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
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$LABSQLServer = Get-LabVM | Where-Object { $_.Roles.Name -like 'SQL*' } | Select-Object -ExpandProperty Name

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
    Write-ScreenInfo -Message "Uploading $KBName to $SQLServer"
    Copy-LabFileItem -Path "$labSources\SoftwarePackages\$KBName" -DestinationFolderPath 'C:\SQLServerCU' -ComputerName $SQLServer

    # Install the latest cumulative update for SQL Server
    Invoke-LabCommand -ActivityName "Installing $KBName on $SQLServer" -ComputerName $SQLServer -ScriptBlock {
        Update-DbaInstance -Path "C:\SQLServerCU\$KBName" -ExtractPath 'C:\SQLServerCU' -Confirm:$false
    } -Variable (Get-Variable KBName) -PassThru

    # Test if reboot is required. If so, reboot the computer.
    if (Test-PendingReboot -ComputerName $SQLServer) {
        Write-ScreenInfo -Message "Reboot of $SQLServer is required after installing CU."
        Restart-LabVM -ComputerName $SQLServer -Wait
    }

    # Check if every SQL Server service is running
    Invoke-LabCommand -ComputerName $SQLServer -ActivityName 'Check if every SQL Server service is running. If not start them.' -ScriptBlock {
        $services = Get-Service -DisplayName 'MSSQL*'
        foreach ($service in $services) {
            if ($service.Status -ne 'Running') {
                Start-Service -Name $service.Name
            }
        }
    } -PassThru
}
