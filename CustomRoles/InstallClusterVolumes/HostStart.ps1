param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [System.Object]
    $VolumeDefinition
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Adding Volumes to Storage Pool on $ComputerName" -ScriptBlock {
    $Pool = Get-StoragePool -FriendlyName 'S2D*'

    foreach ($volume in $VolumeDefinition) {
        $splat = @{
            StoragePool        = $Pool
            FriendlyName       = $volume.FriendlyName
            FileSystem         = $volume.FileSystem
            Size               = $volume.Size
            AllocationUnitSize = $volume.AllocationUnitSize
        }
        New-Volume @splat
    }
} -PassThru -Variable (Get-Variable -Name VolumeDefinition)
