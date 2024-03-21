enum ScaleOutFileServerEnsure {
    Present
    Absent
}

[DscResource()]
class ScaleOutFileServer {
    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [string]
    $IsSingleInstance = 'Yes'

    [DscProperty(Mandatory)]
    [string]
    $Name

    [DscProperty()]
    [ScaleOutFileServerEnsure]
    $Ensure = [ScaleOutFileServerEnsure]::Present

    hidden
    [string]
    $State

    hidden
    [ScaleOutFileServer]
    $CachedCurrentState

    [ScaleOutFileServer] Get() {
        $CurrentState = [ScaleOutFileServer]::new()

        $SofsInfo = Get-ClusterGroup -Name "$($this.Name)" -ErrorAction SilentlyContinue

        if ($null -eq $SofsInfo) {
            $CurrentState.Ensure = 'Absent'
            $CurrentState.Name = $this.Name
            $CurrentState.State = ''
            $CurrentState.IsSingleInstance = $this.IsSingleInstance
        } else {
            $CurrentState.Ensure = 'Present'
            $CurrentState.Name = $SofsInfo.Name
            $CurrentState.State = $SofsInfo.State
            $CurrentState.IsSingleInstance = $this.IsSingleInstance
        }
        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        if ($CurrentState.Ensure -eq 'Present' -and $CurrentState.State -eq 'Online') {
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
        $isAbsent = $CurrentState.Ensure -eq [ScaleOutFileServerEnsure]::Absent

        # The user wants it to be absent, but it is present
        $ShouldBeAbsent = $this.Ensure -eq [ScaleOutFileServerEnsure]::Absent

        if ($IsAbsent) {
            $this.Create($CurrentState)
        } elseif ($ShouldBeAbsent) {
            $this.Remove()
        }
    }

    [void] Create([ScaleOutFileServer] $State) {
        Add-ClusterScaleOutFileServerRole -Name "$($State.Name)"
    }

    [void] Remove([ScaleOutFileServer] $State) {
        Remove-ClusterResource -Name "$($State.Name)" -Force
    }
}
