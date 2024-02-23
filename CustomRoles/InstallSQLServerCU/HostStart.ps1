param(
    [Parameter(Mandatory)]
    [string]
    $KBUri,

    [Parameter(Mandatory)]
    [string]
    [ValidatePattern('^SQLServer\d{4}-KB\d{7}-x64.exe$')]
    $KBName,

    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter()]
    [string]
    $DestinationFolderPath = 'C:\SQLServerCU'
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLServerVersion = $KBName.Split('-')[0]

$LABSQLServer = (Get-LabVM -Role $SQLServerVersion).Name

# Inspired by https://github.com/dataplat/dbatools/blob/master/private/functions/Test-PendingReboot.ps1
function Test-PendingReboot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ComputerName
    )

    $shouldReboot = $false

    $pendingReboot = Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Check Component Based Servicing for Reboot' -ScriptBlock {
        Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing' -Name 'RebootPending' -ErrorAction SilentlyContinue
    } -PassThru
    if ($pendingReboot) {
        $shouldReboot = $true
    }


    # Query WUAU from the registry
    $pendingReboot = Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Check Windows Update RebootRequired for Reboot' -ScriptBlock {
        Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'RebootRequired' -ErrorAction SilentlyContinue
    } -PassThru
    if ($pendingReboot) {
        $shouldReboot = $true
    }

    # Query PendingFileRenameOperations from the registry

    $pendingReboot = Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Check Session Manager PendingFileRenameOperations for Reboot' -ScriptBlock {
        Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    } -PassThru
    if ($pendingReboot -and $pendingReboot.PendingFileRenameOperations) {
        $shouldReboot = $true
    }

    return $shouldReboot
}

foreach($SQLServer in $LABSQLServer) {

    # Test if reboot is required. If so, reboot the computer.
    if (Test-PendingReboot -ComputerName $SQLServer) {
        Write-ScreenInfo -Message "Reboot of $SQLServer is required before installing CU."
        Restart-LabVM -ComputerName $SQLServer -Wait
    }

    # Check if every SQL Server service is running
    Invoke-LabCommand -ComputerName $SQLServer -ActivityName 'Check if every SQL Server service is running. If not wait until they are started.' -ScriptBlock {
        $services = Get-Service -Name '*SQL*'
        foreach ($service in $services) {
            $service.WaitForStatus('Running')
        }
    } -PassThru

    # Download the latest cumulative update for SQL Server
    Write-ScreenInfo -Message "Check if $KBName is already downloaded"
    if (Test-Path "$labSources\SoftwarePackages\$KBName") {
        Write-ScreenInfo -Message "$KBName is already downloaded"
    } else {
        Write-ScreenInfo -Message 'Downloading the latest cumulative update for SQL Server'
        $splat = @{
            Uri  = $KBUri
            Path = "$labSources\SoftwarePackages\$KBName"
        }
        Get-LabInternetFile @splat
    }

    # Upload to Computer $ComputerName
    Write-ScreenInfo -Message "Uploading $KBName to $DestinationFolderPath"
    Copy-LabFileItem -Path "$labSources\SoftwarePackages\$KBName" -DestinationFolderPath $DestinationFolderPath -ComputerName $SQLServer

    # Install the latest cumulative update for SQL Server
    Invoke-LabCommand -ActivityName "Installing $KBName" -ComputerName $SQLServer -ScriptBlock {
        $KBNamePath = Join-Path -Path $DestinationFolderPath -ChildPath $KBName
        Update-DbaInstance -Path $KBNamePath -ExtractPath $DestinationFolderPath -Confirm:$false
    } -Variable (Get-Variable KBName), (Get-Variable -Name DestinationFolderPath) -PassThru

    # Test if reboot is required. If so, reboot the computer.
    if (Test-PendingReboot -ComputerName $SQLServer) {
        Write-ScreenInfo -Message "Reboot of $SQLServer is required after installing CU."
        Restart-LabVM -ComputerName $SQLServer -Wait
    }

    # Check if every SQL Server service is running
    Invoke-LabCommand -ComputerName $SQLServer -ActivityName 'Check if every SQL Server service is running. If not wait until they are started.' -ScriptBlock {
        $services = Get-Service -Name '*SQL*'
        foreach ($service in $services) {
            $service.WaitForStatus('Running')
        }
    } -PassThru
}
