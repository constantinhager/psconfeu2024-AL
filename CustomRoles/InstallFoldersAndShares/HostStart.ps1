param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [System.Object]
    $ClusterFolderAndShareDefinition
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Create Folders and Shares" -ScriptBlock {

    foreach ($folder in $ClusterFolderAndShareDefinition) {

        $splat = @{
            Path     = $folder.Path
            ItemType = 'Directory'
        }
        New-Item @splat

        $splat = @{
            Name       = $folder.Name
            Path       = $folder.Path
            FullAccess = $folder.FullAccess
        }
        New-SmbShare @splat
    }
} -PassThru -Variable (Get-Variable -Name ClusterFolderAndShareDefinition)
