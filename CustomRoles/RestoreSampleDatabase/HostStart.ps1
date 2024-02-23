param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter()]
    [string]
    $CopyDestinationFolderPath = 'C:\SQLServerTestDB',

    [Parameter(Mandatory)]
    [string]
    $RestoreFolderPath,

    [Parameter()]
    [string]
    $DatabaseName = 'AdventureWorksLT2022',

    [Parameter()]
    [string]
    $SampleDatabaseDownloadUri = 'https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak'
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLServerVM = Get-LabVM -ComputerName $ComputerName
$SQLInstance = $SQLServerVM.Roles.Properties.InstanceName

if ([string]::IsNullOrEmpty($SQLInstance)) {
    $SQLInstance = $ComputerName
} else {
    $SQLInstance = [string]::Concat($ComputerName, '\', $SQLInstance)
}

Write-ScreenInfo -Message "Downloading $DatabaseName database backup from $SampleDatabaseDownloadUri"
$Splat = @{
    Uri  = $SampleDatabaseDownloadUri
    Path = "$labSources\SoftwarePackages\$DatabaseName.bak"
}
Get-LabInternetFile @splat

Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Revert SQL Security Settings' -ScriptBlock {
    Set-DbatoolsInsecureConnection
} -PassThru

Write-ScreenInfo -Message "Copying $DatabaseName database backup to $CopyDestinationFolderPath"
$splat = @{
    ComputerName          = $ComputerName
    Path                  = "$labSources\SoftwarePackages\$DatabaseName.bak"
    DestinationFolderPath = $CopyDestinationFolderPath
    PassThru              = $true
}
Copy-LabFileItem @splat

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Restore $DatabaseName" -ScriptBlock {
    Restore-DbaDatabase -SqlInstance $SQLInstance -Path $RestoreFolderPath -DatabaseName $DatabaseName
} -PassThru -Variable (Get-Variable -Name SQLInstance), (Get-Variable -Name RestoreFolderPath), (Get-Variable -Name DatabaseName)

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Change Recovery Model to Full on $DatabaseName" -ScriptBlock {
    Set-DbaDbRecoveryModel -SqlInstance $SQLInstance -Database $DatabaseName -RecoveryModel Full -Confirm:$false
} -PassThru -Variable (Get-Variable -Name SQLInstance), (Get-Variable -Name DatabaseName)
