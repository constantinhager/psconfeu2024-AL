[DSCResource()]
class Reboot {
    [DscProperty(Key)]
    [string]
    $RebootNode = 'True'

    hidden
    [Reboot]
    $CachedCurrentState

    [Reboot] Get() {
        $CurrentState = [Reboot]::new()

        $CurrentState.RebootNode = $this.RebootNode

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        if (($CurrentState.RebootNode -eq 'True') -and ($global:DSCMachineStatus -eq 1)) {
            return $true
        } else {
            return $false
        }
    }

    [void] Set() {
        $global:DSCMachineStatus = 1
    }
}
