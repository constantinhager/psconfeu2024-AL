param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter()]
    [string]
    $FileServerName,

    [Parameter(Mandatory)]
    [System.Object]
    $ClusterFolderAndShareDefinition
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLVMs = (Get-LabVM -Role SQLServer)

if(-not($PSBoundParameters.ContainsKey('FileServerName'))) {
    $FileServerName = $ComputerName
}

foreach ($VM in $SQLVMs) {

    $SQLInstance = $VM.Roles.Properties.InstanceName

    if ([string]::IsNullOrEmpty($SQLInstance)) {
        $SQLInstance = $ComputerName
    } else {
        $SQLInstance = [string]::Concat($ComputerName, '\', $SQLInstance)
    }

    $VMName = $VM.Name
    $DataPath = $ClusterFolderAndShareDefinition.Where({ $_.Name -like "*Data*$VMName" }).Path
    $DataPathFolderName = $DataPath.Split('\')[-1]
    $DataPathNetworkShare = [System.IO.Path]::Combine("\\$FileServerName", $DataPathFolderName)
    $BackupPath = $ClusterFolderAndShareDefinition.Where({ $_.Name -like "*Backup*$VMName" }).Path
    $BackupPathFolderName = $BackupPath.Split('\')[-1]
    $BackupPathNetworkShare = [System.IO.Path]::Combine("\\$FileServerName", $BackupPathFolderName)
    $LogPath = $ClusterFolderAndShareDefinition.Where({ $_.Name -like "*Log*$VMName" }).Path
    $LogPathFolderName = $LogPath.Split('\')[-1]
    $LogPathNetworkShare = [System.IO.Path]::Combine("\\$FileServerName", $LogPathFolderName)

    Invoke-LabCommand -ComputerName $VMName -ActivityName 'Revert SQL Security Settings' -ScriptBlock {
        Set-DbatoolsInsecureConnection
    } -PassThru

    Invoke-LabCommand -ComputerName $VMName -ActivityName 'Change Data, Log and Backup Directories' -ScriptBlock {
        Set-DbaDefaultPath -SqlInstance $SQLInstance -Type Data -Path $DataPathNetworkShare
        Set-DbaDefaultPath -SqlInstance $SQLInstance -Type Backup -Path $BackupPathNetworkShare
        Set-DbaDefaultPath -SqlInstance $SQLInstance -Type Log -Path $LogPathNetworkShare
    } -PassThru -Variable (Get-Variable -Name BackupPathNetworkShare), (Get-Variable -Name DataPathNetworkShare), (Get-Variable -Name LogPathNetworkShare), (Get-Variable -Name SQLInstance)

    Invoke-LabCommand -ComputerName $VMName -ActivityName 'Restart SQL Server Service' -ScriptBlock {
        Get-Service -Name '*SQL*' | Where-Object { $_.Name -notlike '*SQLTELEMETRY*' -and $_.Name -ne 'SQLWriter' } | Restart-Service -Force
    } -PassThru
}
