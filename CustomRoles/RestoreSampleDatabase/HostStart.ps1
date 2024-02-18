param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $DestinationFolderPath,

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
}

$Splat = @{
    Uri  = $SampleDatabaseDownloadUri
    Path = "$labSources\SoftwarePackages\$DatabaseName.bak"
}
Get-LabInternetFile @splat

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Revert SQL Security Settings on $ComputerName" -ScriptBlock {
    Set-DbatoolsInsecureConnection
} -PassThru

$splat = @{
    ComputerName          = $ComputerName
    Path                  = "$labSources\SoftwarePackages\AdventureWorksLT2022.bak"
    DestinationFolderPath = $DestinationFolderPath
    PassThru              = $true
}
Copy-LabFileItem @splat

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Restore AdventureWorksLT2022 on $ComputerName" -ScriptBlock {
    Restore-DbaDatabase -SqlInstance $SQLInstance -Path $DestinationFolderPath -DatabaseName $DatabaseName
} -PassThru -Variable (Get-Variable -Name SQLInstance), (Get-Variable -Name DestinationFolderPath), (Get-Variable -Name DatabaseName)

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Change Recovery Model to Full on AdventureWorksLT2022 on $ComputerName" -ScriptBlock {
    Set-DbaDbRecoveryModel -SqlInstance $SQLInstance -Database $DatabaseName -RecoveryModel Full -Confirm:$false
} -PassThru -Variable (Get-Variable -Name SQLInstance), (Get-Variable -Name DatabaseName)
