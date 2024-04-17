[DSCResource()]
class RestoreDbaDatabase {
    [DscProperty(Key)]
    [string]
    $DatabaseName

    [DscProperty()]
    [string]
    $SqlInstance

    [DscProperty()]
    [string]
    $RestoreFolderPath

    hidden
    [RestoreDbaDatabase]
    $CachedCurrentState

    [RestoreDbaDatabase] Get() {
        $CurrentState = [RestoreDbaDatabase]::new()

        $CurrentState.DatabaseName = $this.DatabaseName
        $CurrentState.SqlInstance = [string]::Concat($env:COMPUTERNAME, '\', $this.SqlInstance)
        $CurrentState.RestoreFolderPath = $this.RestoreFolderPath

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        Set-DbatoolsInsecureConnection

        $splat = @{
            SqlInstance = $CurrentState.SqlInstance
            Database    = $CurrentState.DatabaseName
            ErrorAction = 'SilentlyContinue'
        }
        $DatabaseExists = Get-DbaDatabase @splat

        if ($null -ne $DatabaseExists) {
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

        Set-DbatoolsInsecureConnection

        $splat = @{
            SqlInstance  = $CurrentState.SqlInstance
            Path         = $CurrentState.RestoreFolderPath
            DatabaseName = $CurrentState.DatabaseName
        }
        Restore-DbaDatabase @splat
    }
}

[DSCResource()]
class SetDbaDbRecoveryModel {
    [DscProperty(Key)]
    [string]
    $DatabaseName

    [DscProperty()]
    [string]
    $SqlInstance

    [DscProperty()]
    [ValidateSet('Simple', 'Full', 'BulkLogged')]
    [string]
    $RecoveryModel

    hidden
    [SetDbaDbRecoveryModel]
    $CachedCurrentState

    [SetDbaDbRecoveryModel] Get() {
        $CurrentState = [SetDbaDbRecoveryModel]::new()

        $CurrentState.DatabaseName = $this.DatabaseName
        $CurrentState.SqlInstance = [string]::Concat($env:COMPUTERNAME, '\', $this.SqlInstance)
        $CurrentState.RecoveryModel = $this.RecoveryModel

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        Set-DbatoolsInsecureConnection

        $splat = @{
            SqlInstance   = $CurrentState.SqlInstance
            Database      = $CurrentState.DatabaseName
            RecoveryModel = $CurrentState.RecoveryModel
            ErrorAction   = 'SilentlyContinue'
        }
        $RecoveryModelInfo = Test-DbaDbRecoveryModel @splat

        if ($null -ne $RecoveryModelInfo) {
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

        Set-DbatoolsInsecureConnection

        $splat = @{
            SqlInstance   = $CurrentState.SqlInstance
            RecoveryModel = $CurrentState.RecoveryModel
            Database      = $CurrentState.DatabaseName
            Confirm       = $false
        }
        Set-DbaDbRecoveryModel @splat
    }
}

[DSCResource()]
class PrepareDbaAGDatabase {
    [DscProperty(Key)]
    [string]
    $DatabaseName

    [DscProperty()]
    [string]
    $SqlInstanceNode1

    [DscProperty()]
    [string]
    $SqlInstanceNode2

    [DscProperty()]
    [string]
    $BackupPath

    hidden
    [PrepareDbaAGDatabase]
    $CachedCurrentState

    [PrepareDbaAGDatabase] Get() {
        $CurrentState = [PrepareDbaAGDatabase]::new()

        $CurrentState.DatabaseName = $this.DatabaseName
        $CurrentState.SqlInstanceNode1 = [string]::Concat($env:COMPUTERNAME, '\', $this.SqlInstanceNode1)
        $CurrentState.SqlInstanceNode2 = $this.SqlInstanceNode2
        $CurrentState.BackupPath = $this.BackupPath

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        Set-DbatoolsInsecureConnection

        $splat = @{
            SqlInstance = $CurrentState.SqlInstanceNode2
            Database    = $CurrentState.DatabaseName
            ErrorAction = 'SilentlyContinue'
        }
        $DatabaseInfo = Get-DbaDatabase @splat

        if ($null -ne $DatabaseInfo) {
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

        Set-DbatoolsInsecureConnection

        $splat = @{
            SqlInstance = $CurrentState.SqlInstanceNode1
            Database    = $CurrentState.DatabaseName
            Path        = $CurrentState.BackupPath
            Type        = 'Database'
        }
        Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $CurrentState.SqlInstanceNode2 -NoRecovery

        $splat = @{
            SqlInstance = $CurrentState.SqlInstanceNode1
            Database    = $CurrentState.DatabaseName
            Path        = $CurrentState.BackupPath
            Type        = 'Log'
        }
        Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $CurrentState.SqlInstanceNode2 -Continue -NoRecovery
    }
}

[DSCResource()]
class WaitForDbaInstance {
    [DscProperty(Key)]
    [string]
    $InstanceName

    [DscProperty()]
    [int]
    $RetryIntervalSec = 30

    [DscProperty()]
    [int]
    $RetryCount = 10

    hidden
    [WaitForDbaInstance]
    $CachedCurrentState

    [WaitForDbaInstance] Get() {
        $CurrentState = [WaitForDbaInstance]::new()
        $CurrentState.InstanceName = $this.InstanceName
        $CurrentState.RetryIntervalSec = $this.RetryIntervalSec
        $CurrentState.RetryCount = $this.RetryCount

        $this.CachedCurrentState = $CurrentState
        return $CurrentState
    }

    [bool] Test() {
        $CurrentState = $this.Get()

        $ComputerName = $CurrentState.InstanceName.Split('\')[0]

        $InstanceInfo = Find-DbaInstance -ComputerName $ComputerName

        if ($InstanceInfo.Availability -eq 'Available') {
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

        $ComputerName = $CurrentState.InstanceName.Split('\')[0]

        For ($count = 0; $count -lt $CurrentState.RetryCount; $count++) {
            $InstanceInfo = Find-DbaInstance -ComputerName $ComputerName
            if ($InstanceInfo.Availability -eq 'Available') {
                break
            }
            Start-Sleep -Seconds $CurrentState.RetryIntervalSec
        }
    }
}
