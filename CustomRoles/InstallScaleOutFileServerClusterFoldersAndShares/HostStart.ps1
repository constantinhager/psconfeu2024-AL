param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $SOFSName,

    [Parameter(Mandatory)]
    [System.Object]
    $ClusterFolderAndShareDefinition
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Create Folders and Shares inside of $ClusterName on Scale Out File Server $SOFSName" -ScriptBlock {

    Move-ClusterGroup -Name $SOFSName -Node $ComputerName

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
            ScopeName  = $SOFSName
        }
        New-SmbShare @splat
    }
} -PassThru -Variable (Get-Variable -Name ComputerName), (Get-Variable -Name SOFSName), (Get-Variable -Name ClusterFolderAndShareDefinition)
