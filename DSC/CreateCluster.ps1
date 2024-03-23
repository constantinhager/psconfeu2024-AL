Configuration CreateCluster {

    param
    (
        [Parameter(Mandatory)]
        [pscredential]
        $ActiveDirectoryAdministratorCredential,

        [Parameter(Mandatory)]
        [pscredential]
        $SQLCredential,

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
    Import-DscResource -ModuleName 'SqlServerDsc'
    Import-DscResource -ModuleName 'StorageDsc'

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

        WaitForScaleoutFileServer LAB2SQLSOF {
            Name             = $Node.SOFSName
            RetryIntervalSec = 10
            RetryCount       = 60
        }

        File Data_LAB2SQL1 {
            Ensure          = 'Present'
            DestinationPath = $Node.Data1
            Type            = 'Directory'
            DependsOn       = '[WaitForScaleoutFileServer]LAB2SQLSOF'
        }

        SmbShare Data_LAB2SQL1 {
            Ensure     = 'Present'
            Name       = 'Data_LAB2SQL1'
            Path       = $Node.Data1
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Data_LAB2SQL1'
        }

        File Log_LAB2SQL1 {
            Ensure          = 'Present'
            DestinationPath = $Node.Log1
            Type            = 'Directory'
            DependsOn       = '[WaitForScaleoutFileServer]LAB2SQLSOF'
        }

        SmbShare Log_LAB2SQL1 {
            Ensure     = 'Present'
            Name       = 'Log_LAB2SQL1'
            Path       = $Node.Log1
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Log_LAB2SQL1'
        }

        File Backup_LAB2SQL1 {
            Ensure          = 'Present'
            DestinationPath = $Node.Backup1
            Type            = 'Directory'
            DependsOn       = '[WaitForScaleoutFileServer]LAB2SQLSOF'
        }

        SmbShare Backup_LAB2SQL1 {
            Ensure     = 'Present'
            Name       = 'Backup_LAB2SQL1'
            Path       = $Node.Backup1
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Backup_LAB2SQL1'
        }

        PendingReboot Reboot {
            Name      = 'Reboot test before SQL Server installation'
            DependsOn = @(
                '[SmbShare]Data_LAB2SQL1',
                '[SmbShare]Log_LAB2SQL1',
                '[SmbShare]Backup_LAB2SQL1'
            )
        }

        # TODO: Install PowerShellGet 2.2.5

        MountImage SQLServer {
            ImagePath   = 'C:\Sources\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso'
            DriveLetter = 'D'
            DependsOn   = '[PendingReboot]Reboot'
        }

        WaitForVolume WaitForISO {
            DriveLetter      = 'D'
            RetryIntervalSec = 5
            RetryCount       = 10
            DependsOn        = '[MountImage]SQLServer'
        }

        SqlSetup InstallInstanceSQL1 {
            InstanceName          = $Node.SQLInstanceName
            Features              = 'SQLENGINE'
            SQLCollation          = $Node.SQLCollation
            SQLSvcAccount         = $SQLCredential
            AgtSvcAccount         = $SQLCredential
            SQLSysAdminAccounts   = $Node.SQLSysAdminAccounts
            InstallSharedDir      = 'C:\Program Files\Microsoft SQL Server'
            InstallSharedWOWDir   = 'C:\Program Files (x86)\Microsoft SQL Server'
            InstanceDir           = 'C:\Program Files\Microsoft SQL Server'
            SQLUserDBDir          = $Node.Data1
            SQLUserDBLogDir       = $node.Log1
            SQLTempDBDir          = $Node.Data1
            SQLTempDBLogDir       = $Node.Log1
            SQLBackupDir          = $Node.Backup1
            SourcePath            = 'D:\'
            UpdateEnabled         = 'False'
            ForceReboot           = $false
            SqlSvcStartupType     = 'Automatic'
            BrowserSvcStartupType = 'Automatic'
            AgtSvcStartupType     = 'Automatic'
            PsDscRunAsCredential  = $ActiveDirectoryAdministratorCredential
            DependsOn             = '[WaitForVolume]WaitForISO'
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
            Name                 = $Node.SOFSName
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
            DestinationPath = $Node.Data2
            type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Data_LAB2SQL2 {
            Ensure     = 'Present'
            Name       = 'Data_LAB2SQL2'
            Path       = $Node.Data2
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Data_LAB2SQL2'
        }

        File Log_LAB2SQL2 {
            Ensure          = 'Present'
            DestinationPath = $Node.Log2
            type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Log_LAB2SQL2 {
            Ensure     = 'Present'
            Name       = 'Log_LAB2SQL2'
            Path       = $Node.Log2
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Log_LAB2SQL2'
        }

        File Backup_LAB2SQL2 {
            Ensure          = 'Present'
            DestinationPath = $Node.Backup2
            type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Backup_LAB2SQL2 {
            Ensure     = 'Present'
            Name       = 'Backup_LAB2SQL2'
            Path       = $Node.Backup2
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Backup_LAB2SQL2'
        }

        File SQLSources {
            Ensure          = 'Present'
            DestinationPath = $Node.Sources
            type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare SQLSources {
            Ensure     = 'Present'
            Name       = 'SQLSources'
            Path       = $Node.Sources
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]SQLSources'
        }

        PendingReboot Reboot {
            Name      = 'Reboot test before SQL Server installation'
            DependsOn = @(
                '[SmbShare]Data_LAB2SQL2',
                '[SmbShare]Log_LAB2SQL2',
                '[SmbShare]Backup_LAB2SQL2',
                '[SmbShare]SQLSources'
            )
        }

        MountImage SQLServer {
            ImagePath   = 'C:\Sources\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso'
            DriveLetter = 'D'
            DependsOn   = '[PendingReboot]Reboot'
        }

        WaitForVolume WaitForISO {
            DriveLetter      = 'D'
            RetryIntervalSec = 5
            RetryCount       = 10
            DependsOn        = '[MountImage]SQLServer'
        }

        SqlSetup InstallInstanceSQL2 {
            InstanceName          = $Node.SQLInstanceName
            Features              = 'SQLENGINE'
            SQLCollation          = $Node.SQLCollation
            SQLSvcAccount         = $SQLCredential
            AgtSvcAccount         = $SQLCredential
            SQLSysAdminAccounts   = $Node.SQLSysAdminAccounts
            InstallSharedDir      = 'C:\Program Files\Microsoft SQL Server'
            InstallSharedWOWDir   = 'C:\Program Files (x86)\Microsoft SQL Server'
            InstanceDir           = 'C:\Program Files\Microsoft SQL Server'
            SQLUserDBDir          = $Node.Data2
            SQLUserDBLogDir       = $node.Log2
            SQLTempDBDir          = $Node.Data2
            SQLTempDBLogDir       = $Node.Log2
            SQLBackupDir          = $Node.Backup2
            SourcePath            = 'D:\'
            UpdateEnabled         = 'False'
            ForceReboot           = $false
            SqlSvcStartupType     = 'Automatic'
            BrowserSvcStartupType = 'Automatic'
            AgtSvcStartupType     = 'Automatic'
            PsDscRunAsCredential  = $ActiveDirectoryAdministratorCredential
            DependsOn             = '[WaitForVolume]WaitForISO'
        }
    }
}
