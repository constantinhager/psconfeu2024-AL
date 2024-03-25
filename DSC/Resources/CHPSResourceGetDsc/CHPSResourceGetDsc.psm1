[DSCResource()]
class WaitForGallery {
    [DscProperty(Key)]
    [string]
    $Name = 'PSGallery'

    [DscProperty()]
    [int]
    $RetryIntervalSec = 30

    [DscProperty()]
    [int]
    $RetryCount = 10

    hidden
    [WaitForGallery]
    $CachedCurrentState

    [WaitForGallery] Get() {
        $CurrentState = [WaitForGallery]::new()
        $CurrentState.Name = $this.Name
        $CurrentState.RetryIntervalSec = $this.RetryIntervalSec
        $CurrentState.RetryCount = $this.RetryCount

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        $PSGalleryInfo = Get-PSRepository -Name "$($CurrentState.Name)" -ErrorAction SilentlyContinue

        if ($null -eq $PSGalleryInfo) {
            return $false
        } else {
            return $true
        }
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $CurrentState = $this.CachedCurrentState

        For ($count = 0; $count -lt $CurrentState.RetryCount; $count++) {
            $PSGalleryInfo = Get-PSRepository -Name "$($CurrentState.Name)" -ErrorAction SilentlyContinue
            if ($null -ne $PSGalleryInfo) {
                break
            }
            Start-Sleep -Seconds $CurrentState.RetryIntervalSec
        }
    }
}

enum InstallPSResourceGetEnsure {
    Present
    Absent
}

[DSCResource()]
class InstallPSResourceGet {
    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [string]
    $IsSingleInstance = 'Yes'

    [DscProperty()]
    [InstallPSResourceGetEnsure]
    $Ensure = [InstallPSResourceGetEnsure]::Present

    hidden
    [InstallPSResourceGet]
    $CachedCurrentState

    [InstallPSResourceGet] Get() {
        $CurrentState = [InstallPSResourceGet]::new()

        $ModuleInfo = Get-Module -Name 'Microsoft.PowerShell.PSResourceGet' -ListAvailable

        if ($null -ne $ModuleInfo) {
            $CurrentState.Ensure = [InstallPSResourceGetEnsure]::Present
            $CurrentState.IsSingleInstance = $this.IsSingleInstance
        } else {
            $CurrentState.Ensure = [InstallPSResourceGetEnsure]::Absent
            $CurrentState.IsSingleInstance = $this.IsSingleInstance
        }

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        $ModuleInfo = Get-Module -Name 'Microsoft.PowerShell.PSResourceGet' -ListAvailable

        if ($null -eq $ModuleInfo) {
            return $false
        } else {
            return $true
        }
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $CurrentState = $this.CachedCurrentState

        # Is definatly not there
        $isAbsent = $CurrentState.Ensure -eq [InstallPSResourceGetEnsure]::Absent

        # The user wants it to be absent, but it is present
        $ShouldBeAbsent = $this.Ensure -eq [InstallPSResourceGetEnsure]::Absent

        if ($IsAbsent) {
            $this.Create($CurrentState)
        } elseif ($ShouldBeAbsent) {
            $this.Remove($CurrentState)
        }
    }

    [void] Create([InstallPSResourceGet] $State) {
        if (-not(Get-PackageProvider -Name NuGet -ListAvailable)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }
        Install-Module -Name 'Microsoft.PowerShell.PSResourceGet' -Force
    }

    [void] Remove([InstallPSResourceGet] $State) {
        Uninstall-Module -Name 'Microsoft.PowerShell.PSResourceGet' -Force
    }
}

enum InstallPSResourceGetResourceEnsure {
    Present
    Absent
}

[DSCResource()]
class InstallPSResourceGetResource {
    [DscProperty(Key)]
    [string]
    $Name

    [DscProperty()]
    [InstallPSResourceGetResourceEnsure]
    $Ensure = [InstallPSResourceGetResourceEnsure]::Present

    [DscProperty()]
    [string]
    $Repository = 'PSGallery'

    hidden
    [InstallPSResourceGetResource]
    $CachedCurrentState

    [InstallPSResourceGetResource] Get() {
        $CurrentState = [InstallPSResourceGetResource]::new()

        $Module = Get-Module -Name $this.Name -ListAvailable -ErrorAction SilentlyContinue

        if ($null -ne $Module) {
            $CurrentState.Ensure = [InstallPSResourceGetResourceEnsure]::Present
            $CurrentState.Name = $this.Name
            $CurrentState.Repository = $this.Repository
        } else {
            $CurrentState.Ensure = [InstallPSResourceGetResourceEnsure]::Absent
            $CurrentState.Name = $this.Name
            $CurrentState.Repository = $this.Repository
        }

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        $ModuleInfo = Get-Module -Name $CurrentState.Name -ListAvailable -ErrorAction SilentlyContinue

        if ($null -eq $ModuleInfo) {
            return $false
        } else {
            return $true
        }
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $CurrentState = $this.CachedCurrentState

        # Is definatly not there
        $isAbsent = $CurrentState.Ensure -eq [InstallPSResourceGetResourceEnsure]::Absent

        # The user wants it to be absent, but it is present
        $ShouldBeAbsent = $this.Ensure -eq [InstallPSResourceGetResourceEnsure]::Absent

        if ($IsAbsent) {
            $this.Create($CurrentState)
        } elseif ($ShouldBeAbsent) {
            $this.Remove($CurrentState)
        }
    }

    [void] Create([InstallPSResourceGetResource] $State) {
        Install-PSResource -Name $State.Name -Repository $State.Repository -TrustRepository -Scope AllUsers
    }

    [void] Remove([InstallPSResourceGetResource] $State) {
        Uninstall-PSResource -Name $State.Name -Scope AllUsers
    }
}
