#region PrepareStorageSpacesDirectVolume

[DscResource()]
class PrepareStorageSpacesDirectVolume {
    [DscProperty(Key)]
    [string]
    $DiskNumber

    hidden
    [PrepareStorageSpacesDirectVolume]
    $CachedCurrentState

    [PrepareStorageSpacesDirectVolume] Get() {
        $CurrentState = [PrepareStorageSpacesDirectVolume]::new()
        $CurrentState.DiskNumber = $this.DiskNumber

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        $DiskObject = Get-Disk -Number $CurrentState.DiskNumber

        if ($DiskObject.OperationalStatus -eq 'Online' -and $DiskObject.IsClustered) {
            return $true
        } else {
            return $false
        }
    }

    [void] Set() {

        if ($this.Test()) {
            return
        }

        $CurrentState = $this.CachedCurrentState

        $disk = Get-Disk -Number $CurrentState.DiskNumber
        $disk | Set-Disk -IsOffline:$false
        $disk | Set-Disk -IsReadOnly:$false
        $disk | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
        $disk | Set-Disk -IsReadOnly:$true
        $disk | Set-Disk -IsOffline:$true
    }
}
#endregion PrepareStorageSpacesDirectVolume

# region StorageSpacesDirect
enum StorageSpacesDirectEnsure {
    Present
    Absent
}

[DscResource()]
class StorageSpacesDirect {

    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [string]
    $IsSingleInstance = 'Yes'

    [DscProperty()]
    [StorageSpacesDirectEnsure]
    $Ensure = [StorageSpacesDirectEnsure]::Present

    hidden
    [System.Object]
    $CacheModeHDD

    hidden
    [System.Object]
    $CacheModeSSD

    hidden
    [System.Object]
    $CacheState

    hidden
    [System.Object]
    $State

    hidden
    [uint32]
    $CachePageSizeKBBytes

    hidden
    [uint64]
    $CacheMetadataReservedBytes

    hidden
    [string]
    $Name

    hidden
    [StorageSpacesDirect]
    $CachedCurrentState

    [StorageSpacesDirect] Get() {
        $S2DInfo = Get-ClusterStorageSpacesDirect -WarningAction SilentlyContinue
        $CurrentState = [StorageSpacesDirect]::new()
        $CurrentState.IsSingleInstance = $this.IsSingleInstance
        $CurrentState.CacheModeHDD = $S2DInfo.CacheModeHDD
        $CurrentState.CacheModeSSD = $S2DInfo.CacheModeSSD
        $CurrentState.CacheState = $S2DInfo.CacheState
        $CurrentState.State = $S2DInfo.State
        $CurrentState.CachePageSizeKBBytes = $S2DInfo.CachePageSizeKBBytes
        $CurrentState.CacheMetadataReservedBytes = $S2DInfo.CacheMetadataReservedBytes
        $CurrentState.Name = $S2DInfo.Name

        if ($S2DInfo.State -eq 'Enabled') {
            $CurrentState.Ensure = [StorageSpacesDirectEnsure]::Present
        } else {
            $CurrentState.Ensure = [StorageSpacesDirectEnsure]::Absent
        }

        $this.CachedCurrentState = $CurrentState

        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        if ($CurrentState.State -eq 'Enabled') {
            return $true
        } else {
            return $false
        }
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $CurrentState = $this.CachedCurrentState

        # Is definatly not there
        $isAbsent = $CurrentState.Ensure -eq [StorageSpacesDirectEnsure]::Absent

        # The user wants it to be absent, but it is present
        $ShouldBeAbsent = $this.Ensure -eq [StorageSpacesDirectEnsure]::Absent

        if ($IsAbsent) {
            $this.Create()
        } elseif ($ShouldBeAbsent) {
            $this.Remove()
        }
    }

    [void] Create() {
        Enable-ClusterStorageSpacesDirect -Confirm:$false -WarningAction SilentlyContinue
    }

    [void] Remove() {
        Disable-ClusterStorageSpacesDirect -Confirm:$false -WarningAction SilentlyContinue
    }
}
#endregion StorageSpacesDirect

# region StorageSpacesDirectVolume
enum StorageSpacesDirectVolumeEnsure {
    Present
    Absent
}
[DscResource()]
class StorageSpacesDirectVolume {
    [DscProperty(Key)]
    [string]
    $FriendlyName

    [DscProperty(Mandatory)]
    [string]
    $StoragePoolFriendlyName

    [DscProperty(Mandatory)]
    [ValidateSet('CSVFS_NTFS', 'CSVFS_ReFS')]
    [string]
    $FileSystem

    [DscProperty(Mandatory)]
    [uint64]
    $Size

    [DscProperty()]
    [StorageSpacesDirectVolumeEnsure]
    $Ensure = [StorageSpacesDirectVolumeEnsure]::Present

    hidden
    [StorageSpacesDirectVolume]
    $CachedCurrentState

    [StorageSpacesDirectVolume] Get() {
        $VolumeInfo = Get-Volume -StoragePool (Get-StoragePool -FriendlyName "$($this.StoragePoolFriendlyName)") |
        Where-Object { $_.FileSystemLabel -eq $this.FriendlyName }
        $CurrentState = [StorageSpacesDirectVolume]::new()

        if ($null -ne $VolumeInfo) {
            $CurrentState.Ensure = [StorageSpacesDirectEnsure]::Present
            $CurrentState.Size = $VolumeInfo.Size
            $CurrentState.FileSystem = $VolumeInfo.FileSystemType
            $CurrentState.FriendlyName = $VolumeInfo.FileSystemLabel
            $CurrentState.StoragePoolFriendlyName = $this.StoragePoolFriendlyName
        } else {
            $CurrentState.Ensure = [StorageSpacesDirectEnsure]::Absent
            $CurrentState.Size = $this.Size
            $CurrentState.FileSystem = $this.FileSystem
            $CurrentState.FriendlyName = $this.FriendlyName
            $CurrentState.StoragePoolFriendlyName = $this.StoragePoolFriendlyName
        }

        $this.CachedCurrentState = $CurrentState

        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        if ($CurrentState.Ensure -eq [StorageSpacesDirectEnsure]::Present) {
            return $true
        } else {
            return $false
        }
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $CurrentState = $this.CachedCurrentState

        # Is definatly not there
        $isAbsent = $CurrentState.Ensure -eq [StorageSpacesDirectEnsure]::Absent

        # The user wants it to be absent, but it is present
        $ShouldBeAbsent = $this.Ensure -eq [StorageSpacesDirectEnsure]::Absent

        if ($IsAbsent) {
            $this.Create($CurrentState)
        } elseif ($ShouldBeAbsent) {
            $this.Remove($CurrentState)
        }
    }

    [void] Create([StorageSpacesDirectVolume]$State) {
        $splat = @{
            StoragePoolFriendlyName = "$($State.StoragePoolFriendlyName)"
            FriendlyName            = "$($State.FriendlyName)"
            FileSystem              = "$($State.FileSystem)"
            Size                    = "$($State.Size)"
        }
        New-Volume @splat
    }

    [void] Remove([StorageSpacesDirectVolume]$State) {
        $PDToRemove = Get-PhysicalDisk -FriendlyName $State.FriendlyName
        Remove-PhysicalDisk -PhysicalDisks $PDToRemove -StoragePoolFriendlyName $state.StoragePoolFriendlyName -Confirm:$false
    }
}
# endregion StorageSpacesDirectVolume
