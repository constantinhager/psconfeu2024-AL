param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [System.Object]
    $ClusterFolderAndShareDefinition
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$LabVM = Get-LabVM -Role SQLServer

$SourcePath = $ClusterFolderAndShareDefinition.Where({ $_.Name -like '*Sources*' }).Path

foreach ($VM in $LabVM) {
    $SQLSvcAccount = $VM.roles.Properties.SQLSvcAccount
    $Paths = $ClusterFolderAndShareDefinition.Where({ $_.Name -like "*$($VM.Name)" }).Path

    foreach ($Path in $Paths) {
        Invoke-LabCommand -ComputerName $VM.Name -ActivityName "Set SQL Service Account Permissions on Path $Path" -ScriptBlock {
            Add-NTFSAccess -Path $Path -Account $SQLSvcAccount -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles
        } -PassThru -Variable (Get-Variable -Name Path), (Get-Variable -Name SQLSvcAccount)
    }

    Invoke-LabCommand -ComputerName $VM.Name -ActivityName "Set SQL Service Account Permissions on Path $SourcePath" -ScriptBlock {
        Add-NTFSAccess -Path $SourcePath -Account $SQLSvcAccount -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles
    } -PassThru -Variable (Get-Variable -Name SourcePath), (Get-Variable -Name SQLSvcAccount)

    Write-ScreenInfo -Message "Reboot of $($VM.Name) to recognize the new permissions."
    Restart-LabVM -ComputerName $VM.Name -Wait
}
