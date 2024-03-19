$ModuleSettings = @{
    RootModule           = 'CHStorageSpacesDirectDsc.psm1'
    DscResourcesToExport = 'StorageSpacesDirectVolume'
    Path                 = "$PSScriptRoot\CHStorageSpacesDirectDsc\CHStorageSpacesDirectDsc.psd1"
}
New-ModuleManifest @ModuleSettings

$splat = @{
    Path     = "$PSScriptRoot\CHStorageSpacesDirectDsc\CHStorageSpacesDirectDsc.psm1"
    ItemType = 'File'
}
New-Item @splat

$splat = @{
    Path     = "$PSScriptRoot\CHStorageSpacesDirectDsc\Helpers.ps1"
    ItemType = 'File'
}
New-Item @splat
