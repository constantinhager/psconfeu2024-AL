Configuration CreateCluster {

    param
    (
        [Parameter(Mandatory)]
        [pscredential]
        $ActiveDirectoryAdministratorCredential,

        [Parameter(Mandatory)]
        [string]
        $ClusterName,

        [Parameter(Mandatory)]
        [string]
        $ClusterIPAddress,

        [Parameter(Mandatory)]
        [string]
        $StorageAccountName,

        [Parameter(Mandatory)]
        [string]
        $StorageAccountAccessKey
    )

    Import-DscResource -ModuleName 'FailoverClusterDSC'
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'CHStorageSpacesDirectDsc'
    Import-DscResource -ModuleName 'CHScaleOutFileServerDsc'

    node $AllNodes.Where({ $_.Role -eq 'FirstNode' }).NodeName {

        WindowsFeature AddFileServerFeature {
            Ensure = 'Present'
            Name   = 'FS-FileServer'
        }

        WindowsFeature AddFailoverFeature {
            Ensure    = 'Present'
            Name      = 'Failover-Clustering'
            DependsOn = '[WindowsFeature]AddFileServerFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringPowerShellFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]AddFailoverFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-CmdInterface'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusterManagementTool {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-Mgmt'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        Cluster SQLCluster {
            Name                          = $ClusterName
            DomainAdministratorCredential = $ActiveDirectoryAdministratorCredential
            StaticIPAddress               = $ClusterIPAddress
            DependsOn                     = '[WindowsFeature]AddRemoteServerAdministrationToolsClusterManagementTool'
        }

        ClusterQuorum SQLClusterQuorum {
            IsSingleInstance        = 'Yes'
            Type                    = 'NodeAndCloudMajority'
            Resource                = $StorageAccountName
            StorageAccountAccessKey = $StorageAccountAccessKey
            DependsOn               = '[Cluster]SQLCluster'
        }

        $DiskInfo = Invoke-LabCommand -ComputerName ($AllNodes.Where({ $_.Role -eq 'FirstNode' }).NodeName) -ScriptBlock {
            Get-Disk | Where-Object Number -NE $null | Where-Object IsBoot -NE $true | Where-Object IsSystem -NE $true | Where-Object PartitionStyle -NE RAW
        } -PassThru -NoDisplay

        foreach ($disk in $DiskInfo) {
            PrepareStorageSpacesDirectVolume "$($disk.Number)" {
                DiskNumber = $disk.Number
                DependsOn  = '[ClusterQuorum]SQLClusterQuorum'
            }
        }
    }

    node $AllNodes.Where({ $_.Role -eq 'SecondNode' }).NodeName {
        WindowsFeature AddFileServerFeature {
            Ensure = 'Present'
            Name   = 'FS-FileServer'
        }

        WindowsFeature AddFailoverFeature {
            Ensure    = 'Present'
            Name      = 'Failover-Clustering'
            DependsOn = '[WindowsFeature]AddFileServerFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringPowerShellFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]AddFailoverFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-CmdInterface'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusterManagementTool {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-Mgmt'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        WaitForCluster WaitForCluster {
            Name             = $ClusterName
            RetryIntervalSec = 10
            RetryCount       = 60
            DependsOn        = '[WindowsFeature]AddRemoteServerAdministrationToolsClusterManagementTool'
        }

        Cluster SQLCluster {
            Name                          = $ClusterName
            DomainAdministratorCredential = $ActiveDirectoryAdministratorCredential
            StaticIPAddress               = $ClusterIPAddress
            DependsOn                     = '[WaitForCluster]WaitForCluster'
        }

        $DiskInfo = Invoke-LabCommand -ComputerName ($AllNodes.Where({ $_.Role -eq 'SecondNode' }).NodeName) -ScriptBlock {
            Get-Disk | Where-Object Number -NE $null | Where-Object IsBoot -NE $true | Where-Object IsSystem -NE $true | Where-Object PartitionStyle -NE RAW
        } -PassThru -NoDisplay

        foreach ($disk in $DiskInfo) {
            PrepareStorageSpacesDirectVolume "$($disk.Number)" {
                DiskNumber = $disk.Number
                DependsOn  = '[Cluster]SQLCluster'
            }
        }

        StorageSpacesDirect EnableS2D {
            IsSingleInstance = 'Yes'
            Ensure           = 'Present'
        }

        StorageSpacesDirectVolume SQLData {
            FriendlyName            = 'SQLData'
            StoragePoolFriendlyName = 'S2D*'
            Size                    = 20GB
            FileSystem              = 'CSVFS_ReFS'
            Ensure                  = 'Present'
            DependsOn               = '[StorageSpacesDirect]EnableS2D'
        }

        StorageSpacesDirectVolume SQLLog {
            FriendlyName            = 'SQLLog'
            StoragePoolFriendlyName = 'S2D*'
            Size                    = 20GB
            FileSystem              = 'CSVFS_ReFS'
            Ensure                  = 'Present'
            DependsOn               = '[StorageSpacesDirect]EnableS2D'
        }

        StorageSpacesDirectVolume SQLBackup {
            FriendlyName            = 'SQLBackup'
            StoragePoolFriendlyName = 'S2D*'
            Size                    = 10GB
            FileSystem              = 'CSVFS_ReFS'
            Ensure                  = 'Present'
            DependsOn               = '[StorageSpacesDirect]EnableS2D'
        }

        StorageSpacesDirectVolume SQLSources {
            FriendlyName            = 'SQLSources'
            StoragePoolFriendlyName = 'S2D*'
            Size                    = 20GB
            FileSystem              = 'CSVFS_ReFS'
            Ensure                  = 'Present'
            DependsOn               = '[StorageSpacesDirect]EnableS2D'
        }

        ScaleOutFileServer LAB2SQLSOF {
            IsSingleInstance     = 'Yes'
            Name                 = 'LAB2SQLSOF'
            Ensure               = 'Present'
            DependsOn            = @(
                '[StorageSpacesDirectVolume]SQLData',
                '[StorageSpacesDirectVolume]SQLLog',
                '[StorageSpacesDirectVolume]SQLBackup',
                '[StorageSpacesDirectVolume]SQLSources'
            )
            # Problem: Add-ClusterScaleOutFileServerRole does not support
            # to be executed over a remote session. It has to be executed
            # on the cluster node itself. For this reason, we have to
            # use PSDSCRunAsCredential to execute the command on the
            # cluster node.
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        File Data_LAB2SQL2 {
            Ensure          = 'Present'
            DestinationPath = 'C:\ClusterStorage\SQLData\Shares\Data_LAB2SQL2'
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Data_LAB2SQL2 {
            Ensure     = 'Present'
            Name       = 'Data_LAB2SQL2'
            Path       = 'C:\ClusterStorage\SQLData\Shares\Data_LAB2SQL2'
            ScopeName  = 'LAB2SQLSOF'
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Data_LAB2SQL2'
        }

        File Log_LAB2SQL2 {
            Ensure          = 'Present'
            DestinationPath = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB2SQL2'
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Log_LAB2SQL2 {
            Ensure     = 'Present'
            Name       = 'Log_LAB2SQL2'
            Path       = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB2SQL2'
            ScopeName  = 'LAB2SQLSOF'
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Log_LAB2SQL2'
        }

        File Backup_LAB2SQL2 {
            Ensure          = 'Present'
            DestinationPath = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB2SQL2'
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Backup_LAB2SQL2 {
            Ensure     = 'Present'
            Name       = 'Backup_LAB2SQL2'
            Path       = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB2SQL2'
            ScopeName  = 'LAB2SQLSOF'
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Backup_LAB2SQL2'
        }

        File Data_LAB2SQL1 {
            Ensure          = 'Present'
            DestinationPath = 'C:\ClusterStorage\SQLData\Shares\Data_LAB2SQL1'
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Data_LAB2SQL1 {
            Ensure     = 'Present'
            Name       = 'Data_LAB2SQL1'
            Path       = 'C:\ClusterStorage\SQLData\Shares\Data_LAB2SQL1'
            ScopeName  = 'LAB2SQLSOF'
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Data_LAB2SQL1'
        }

        File Log_LAB2SQL1 {
            Ensure          = 'Present'
            DestinationPath = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB2SQL1'
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Log_LAB2SQL1 {
            Ensure     = 'Present'
            Name       = 'Log_LAB2SQL1'
            Path       = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB2SQL1'
            ScopeName  = 'LAB2SQLSOF'
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Log_LAB2SQL1'
        }

        File Backup_LAB2SQL1 {
            Ensure          = 'Present'
            DestinationPath = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB2SQL1'
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Backup_LAB2SQL1 {
            Ensure     = 'Present'
            Name       = 'Backup_LAB2SQL1'
            Path       = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB2SQL1'
            ScopeName  = 'LAB2SQLSOF'
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Backup_LAB2SQL1'
        }

        File SQLSources {
            Ensure          = 'Present'
            DestinationPath = 'C:\ClusterStorage\SQLSources\Shares\Sources'
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare SQLSources {
            Ensure     = 'Present'
            Name       = 'SQLSources'
            Path       = 'C:\ClusterStorage\SQLSources\Shares\Sources'
            ScopeName  = 'LAB2SQLSOF'
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]SQLSources'
        }
    }
}
