[DscResource()]
class StorageSpacesDirectVolume {
    [DscProperty(Key)]
    [string]
    $DiskNumber

    hidden
    [StorageSpacesDirectVolume]
    $CachedCurrentState

    [StorageSpacesDirectVolume] Get() {
        $CurrentState = [StorageSpacesDirectVolume]::new()
        $CurrentState.DiskNumber = $this.DiskNumber

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        $DiskObject = Get-Disk -Number $CurrentState.DiskNumber

        if ($DiskObject.OperationalStatus -ne 'Online') {
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
