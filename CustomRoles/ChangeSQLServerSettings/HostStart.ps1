param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [System.Object]
    $ClusterFolderAndShareDefinition
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLVMs = (Get-LabVM -Role SQLServer).Name

foreach ($VM in $SQLVMs) {
    Invoke-LabCommand -ComputerName $VM -ActivityName 'Change Data, Log and Backup Directories' -ScriptBlock {
        Set-DbaDefaultPath -SqlInstance sql01\sharepoint -Type Data -Path $DataPath
        Set-DbaDefaultPath -SqlInstance sql01\sharepoint -Type Backup -Path $BackupPath
        Set-DbaDefaultPath -SqlInstance sql01\sharepoint -Type Log -Path $LogPath
    } -PassThru -Variable (Get-Variable -Name BackupPath), (Get-Variable -Name DataPath), (Get-Variable -Name LogPath)
}
