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

$ModuleSettings = @{
    RootModule           = 'CHScaleOutFileServerDsc.psm1'
    DscResourcesToExport = 'ScaleOutFileServer'
    Path                 = "$PSScriptRoot\CHStorageSpacesDirectDsc\CHScaleOutFileServerDsc.psd1"
}
New-ModuleManifest @ModuleSettings

$splat = @{
    Path     = "$PSScriptRoot\CHScaleOutFileServerDsc\CHScaleOutFileServerDsc.psm1"
    ItemType = 'File'
}
New-Item @splat
