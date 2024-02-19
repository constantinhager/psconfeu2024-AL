param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter()]
    [string]
    $DestinationFolderPath = 'C:\SQLServerTestDB',

    [Parameter()]
    [string]
    $SQLInstance = 'MSSQLSERVER',

    [Parameter()]
    [string]
    $DatabaseName = 'AdventureWorksLT2022',

    [Parameter()]
    [string]
    $SampleDatabaseDownloadUri = 'https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak'
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

if (-not ($SQLInstance.ToUpper() -eq 'MSSQLSERVER')) {
    $SQLInstance = [string]::Concat($ComputerName, '\', $SQLInstance)
} else {
    $SQLInstance = $ComputerName
}

Write-ScreenInfo -Message "Downloading $DatabaseName database backup from $SampleDatabaseDownloadUri"
$Splat = @{
    Uri  = $SampleDatabaseDownloadUri
    Path = "$labSources\SoftwarePackages\$DatabaseName.bak"
}
Get-LabInternetFile @splat

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Revert SQL Security Settings" -ScriptBlock {
    Set-DbatoolsInsecureConnection
} -PassThru

Write-ScreenInfo -Message "Copying $DatabaseName database backup to $DestinationFolderPath"
$splat = @{
    ComputerName          = $ComputerName
    Path                  = "$labSources\SoftwarePackages\$DatabaseName.bak"
    DestinationFolderPath = $DestinationFolderPath
    PassThru              = $true
}
Copy-LabFileItem @splat

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Restore $DatabaseName" -ScriptBlock {
    Restore-DbaDatabase -SqlInstance $SQLInstance -Path $DestinationFolderPath -DatabaseName $DatabaseName
} -PassThru -Variable (Get-Variable -Name SQLInstance), (Get-Variable -Name DestinationFolderPath), (Get-Variable -Name DatabaseName)

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Change Recovery Model to Full on $DatabaseName" -ScriptBlock {
    Set-DbaDbRecoveryModel -SqlInstance $SQLInstance -Database $DatabaseName -RecoveryModel Full -Confirm:$false
} -PassThru -Variable (Get-Variable -Name SQLInstance), (Get-Variable -Name DatabaseName)
