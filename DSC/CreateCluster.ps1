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
        $SQLSVCUserName,

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
    Import-DscResource -ModuleName 'CHPSResourceGetDsc'
    Import-DscResource -ModuleName 'CHDBAToolsDsc'
    Import-DscResource -ModuleName 'SqlServerDsc'
    Import-DscResource -ModuleName 'StorageDsc'
    Import-DscResource -ModuleName 'AccessControlDSC'

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

        PendingReboot Reboot {
            Name      = 'Reboot test before SQL Server installation'
            DependsOn = @(
                '[WaitForScaleoutFileServer]LAB2SQLSOF'
            )
        }

        PSResourceRepository PSGallery {
            Name      = 'PSGallery'
            Ensure    = 'Present'
            Default   = $true
            DependsOn = '[PendingReboot]Reboot'
        }

        InstallPSResourceGet PSResourceGet {
            IsSingleInstance = 'Yes'
            Ensure           = 'Present'
            DependsOn        = '[PSResourceRepository]PSGallery'
        }

        InstallPSResourceGetResource dbatoolsModule {
            Name      = 'dbatools'
            Ensure    = 'Present'
            DependsOn = '[InstallPSResourceGet]PSResourceGet'
        }

        InstallPSResourceGetResource SqlServerModule {
            Name      = 'SqlServer'
            Ensure    = 'Present'
            DependsOn = '[InstallPSResourceGet]PSResourceGet'
        }

        MountImage SQLServer {
            ImagePath   = 'C:\Sources\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso'
            DriveLetter = 'D'
            DependsOn   = '[InstallPSResourceGetResource]SqlServerModule'
            Ensure      = 'Present'
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
            UpdateEnabled         = 'True'
            UpdateSource          = 'C:\Sources'
            ForceReboot           = $false
            SqlSvcStartupType     = 'Automatic'
            BrowserSvcStartupType = 'Automatic'
            AgtSvcStartupType     = 'Automatic'
            PsDscRunAsCredential  = $ActiveDirectoryAdministratorCredential
            DependsOn             = '[WaitForVolume]WaitForISO'
        }

        PendingReboot RebootAfterSQL1 {
            Name      = 'Reboot test before SQL Server installation'
            DependsOn = @(
                '[SqlSetup]InstallInstanceSQL1'
            )
        }

        Service SQLBrowser {
            Name      = 'SQLBrowser'
            State     = 'Running'
            DependsOn = @(
                '[PendingReboot]RebootAfterSQL1'
            )
        }

        Service SQLServerService {
            Name      = 'MSSQLSERVER'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLBrowser'
            )
        }

        Service SQLServerAgent {
            Name      = 'SQLSERVERAGENT'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLServerService'
            )
        }

        Service SQLTelemetry {
            Name      = 'SQLTELEMETRY'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLServerAgent'
            )
        }

        Service SQLWriter {
            Name      = 'SQLWriter'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLTelemetry'
            )
        }

        SqlLogin Add_WindowsUserSqlSvc {
            Ensure               = 'Present'
            Name                 = $SQLSVCUserName
            LoginType            = 'WindowsUser'
            InstanceName         = $Node.SQLInstanceName
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
            DependsOn            = '[Service]SQLWriter'
        }

        SqlLogin Add_WindowsUserClusSvc {
            Ensure               = 'Present'
            Name                 = 'NT SERVICE\ClusSvc'
            LoginType            = 'WindowsUser'
            InstanceName         = $Node.SQLInstanceName
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
            DependsOn            = '[Service]SQLWriter'
        }

        SqlLogin Add_ClusterMember {
            Ensure               = 'Present'
            Name                 = ('CONTOSO\{0}$' -f $Node.SQLNode2)
            LoginType            = 'WindowsUser'
            InstanceName         = $Node.SQLInstanceName
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
            DependsOn            = '[Service]SQLWriter'
        }

        SqlPermission SQLConfigureServerPermissionSYSTEMSvc {
            InstanceName = $Node.SQLInstanceName
            Name         = $SQLSVCUserName
            Permission   = @(
                ServerPermission {
                    State      = 'Grant'
                    Permission = @('AlterAnyAvailabilityGroup', 'ViewServerState', 'AlterAnyEndPoint', 'ConnectSql')
                }
                ServerPermission {
                    State      = 'GrantWithGrant'
                    Permission = @()
                }
                ServerPermission {
                    State      = 'Deny'
                    Permission = @()
                }
            )
            DependsOn    = '[SqlLogin]Add_WindowsUserClusSvc'
        }

        SqlPermission AddNTServiceClusSvcPermissions {
            InstanceName = $Node.SQLInstanceName
            Name         = 'NT SERVICE\ClusSvc'
            Permission   = @(
                ServerPermission {
                    State      = 'Grant'
                    Permission = @('AlterAnyAvailabilityGroup', 'ViewServerState', 'ConnectSql')
                }
                ServerPermission {
                    State      = 'GrantWithGrant'
                    Permission = @()
                }
                ServerPermission {
                    State      = 'Deny'
                    Permission = @()
                }
            )
            DependsOn    = '[SqlLogin]Add_WindowsUserClusSvc'
        }

        SqlRole Add_SysAdmins {
            Ensure               = 'Present'
            ServerRoleName       = 'sysadmin'
            MembersToInclude     = $SQLSVCUserName, ('CONTOSO\{0}$' -f $Node.SQLNode2)
            InstanceName         = $Node.SQLInstanceName
            DependsOn            = '[SqlLogin]Add_WindowsUserSqlSvc', '[SqlLogin]Add_ClusterMember'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        SqlEndpoint HADREndpoint {
            EndPointName         = 'HADR'
            EndpointType         = 'DatabaseMirroring'
            Port                 = 5022
            InstanceName         = $Node.SQLInstanceName
            DependsOn            = '[SqlRole]Add_SysAdmins'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        SqlAlwaysOnService EnableHADR {
            Ensure               = 'Present'
            InstanceName         = $Node.SQLInstanceName
            DependsOn            = '[SqlEndpoint]HADREndpoint'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        RestoreDbaDatabase AdventureWorks {
            DatabaseName      = 'AdventureWorks'
            SqlInstance       = $Node.SQLInstanceName
            RestoreFolderPath = 'C:\Sources\AdventureWorksLT2022.bak'
            DependsOn         = '[SqlAlwaysOnService]EnableHADR'
        }

        SetDbaDbRecoveryModel AdventureWorksRecoveryModel {
            DatabaseName  = 'AdventureWorks'
            SqlInstance   = $Node.SQLInstanceName
            RecoveryModel = 'FULL'
            DependsOn     = '[RestoreDbaDatabase]AdventureWorks'
        }

        WaitForDbaInstance SecondNode {
            InstanceName     = $Node.SQLInstanceNode2
            RetryCount       = 60
            RetryIntervalSec = 10
            DependsOn        = '[SetDbaDbRecoveryModel]AdventureWorksRecoveryModel'
        }

        PrepareDbaAGDatabase AdventureWorks {
            DatabaseName         = 'AdventureWorks'
            SqlInstanceNode1     = $Node.SQLInstanceName
            SqlInstanceNode2     = $Node.SQLInstanceNode2
            BackupPath           = $Node.Backup1
            DependsOn            = '[WaitForDbaInstance]SecondNode'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        SqlAG LAB2SQLAG {
            Ensure                 = 'Present'
            Name                   = $Node.SQLAvailabilityGroupName
            InstanceName           = $Node.SQLInstanceName
            ServerName             = $Node.NodeName
            FailoverMode           = 'Automatic'
            AvailabilityMode       = 'SynchronousCommit'
            BasicAvailabilityGroup = $false
            DatabaseHealthTrigger  = $true
            DtcSupportEnabled      = $true
            DependsOn              = '[SqlAlwaysOnService]EnableHADR', '[SqlEndpoint]HADREndpoint', '[SqlPermission]AddNTServiceClusSvcPermissions'
            PsDscRunAsCredential   = $ActiveDirectoryAdministratorCredential
        }

        SqlAGListener 'LAB2SQLAGListener' {
            Ensure                  = 'Present'
            ServerName              = $Node.NodeName
            InstanceName            = $Node.SQLInstanceName
            AvailabilityGroup       = $Node.SQLAvailabilityGroupName
            Name                    = $Node.SQLAvailabilityGroupName
            IpAddress               = $Node.SQLAvailabilityGroupIPAddress
            Port                    = 1433
            ProcessOnlyOnActiveNode = $true
            PsDscRunAsCredential    = $ActiveDirectoryAdministratorCredential
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
            Type            = 'Directory'
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
            Type            = 'Directory'
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
            Type            = 'Directory'
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
            Type            = 'Directory'
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

        File Data_LAB2SQL1 {
            Ensure          = 'Present'
            DestinationPath = $Node.Data1
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
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
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
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
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
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

        File Backup_LAB2SQLAG {
            Ensure          = 'Present'
            DestinationPath = $Node.SQLAvailabilityGroupBackupDir
            Type            = 'Directory'
            DependsOn       = '[ScaleOutFileServer]LAB2SQLSOF'
        }

        SmbShare Backup_LAB2SQLAG {
            Ensure     = 'Present'
            Name       = 'Backup_LAB2SQLAG'
            Path       = $Node.SQLAvailabilityGroupBackupDir
            ScopeName  = $Node.SOFSName
            FullAccess = @(
                'Everyone'
            )
            DependsOn  = '[File]Backup_LAB2SQLAG'
        }

        NTFSAccessEntry Backup_LAB2SQLAG {
            Path              = $Node.SQLAvailabilityGroupBackupDir
            AccessControlList = @(
                NTFSAccessControlList {
                    Principal          = 'contoso\sqlsvc'
                    ForcePrincipal     = $true
                    AccessControlEntry = @(
                        NTFSAccessControlEntry {
                            AccessControlType = 'Allow'
                            FileSystemRights  = 'FullControl'
                            Inheritance       = 'This folder subfolders and files'
                            Ensure            = 'Present'
                        }
                    )
                }
            )
            DependsOn         = '[SmbShare]Backup_LAB2SQLAG', '[File]Backup_LAB2SQLAG'
        }

        PendingReboot Reboot {
            Name      = 'Reboot test before SQL Server installation'
            DependsOn = @(
                '[NTFSAccessEntry]Backup_LAB2SQLAG'
            )
        }

        PSResourceRepository PSGallery {
            Name      = 'PSGallery'
            Ensure    = 'Present'
            Default   = $true
            DependsOn = '[PendingReboot]Reboot'
        }

        InstallPSResourceGet PSResourceGet {
            IsSingleInstance = 'Yes'
            Ensure           = 'Present'
            DependsOn        = '[PSResourceRepository]PSGallery'
        }

        InstallPSResourceGetResource dbatoolsModule {
            Name      = 'dbatools'
            Ensure    = 'Present'
            DependsOn = '[InstallPSResourceGet]PSResourceGet'
        }

        InstallPSResourceGetResource SqlServerModule {
            Name      = 'SqlServer'
            Ensure    = 'Present'
            DependsOn = '[InstallPSResourceGet]PSResourceGet'
        }

        MountImage SQLServer {
            ImagePath   = 'C:\Sources\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso'
            DriveLetter = 'D'
            DependsOn   = '[InstallPSResourceGetResource]SqlServerModule'
            Ensure      = 'Present'
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
            UpdateEnabled         = 'True'
            UpdateSource          = 'C:\Sources'
            ForceReboot           = $false
            SqlSvcStartupType     = 'Automatic'
            BrowserSvcStartupType = 'Automatic'
            AgtSvcStartupType     = 'Automatic'
            PsDscRunAsCredential  = $ActiveDirectoryAdministratorCredential
            DependsOn             = '[WaitForVolume]WaitForISO'
        }

        PendingReboot RebootAfterSQL2 {
            Name      = 'Reboot test before SQL Server installation'
            DependsOn = @(
                '[SqlSetup]InstallInstanceSQL2'
            )
        }

        Service SQLBrowser {
            Name      = 'SQLBrowser'
            State     = 'Running'
            DependsOn = @(
                '[PendingReboot]RebootAfterSQL2'
            )
        }

        Service SQLServerService {
            Name      = 'MSSQLSERVER'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLBrowser'
            )
        }

        Service SQLServerAgent {
            Name      = 'SQLSERVERAGENT'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLServerService'
            )
        }

        Service SQLTelemetry {
            Name      = 'SQLTELEMETRY'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLServerAgent'
            )
        }

        Service SQLWriter {
            Name      = 'SQLWriter'
            State     = 'Running'
            DependsOn = @(
                '[Service]SQLTelemetry'
            )
        }

        SqlLogin Add_WindowsUserSqlSvc {
            Ensure               = 'Present'
            Name                 = $SQLSVCUserName
            LoginType            = 'WindowsUser'
            InstanceName         = $Node.SQLInstanceName
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
            DependsOn            = '[Service]SQLWriter'
        }

        SqlLogin Add_WindowsUserClusSvc {
            Ensure               = 'Present'
            Name                 = 'NT SERVICE\ClusSvc'
            LoginType            = 'WindowsUser'
            InstanceName         = $Node.SQLInstanceName
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
            DependsOn            = '[Service]SQLWriter'
        }

        SqlPermission SQLConfigureServerPermissionSYSTEMSvc {
            InstanceName = $Node.SQLInstanceName
            Name         = $SQLSVCUserName
            Permission   = @(
                ServerPermission {
                    State      = 'Grant'
                    Permission = @('AlterAnyAvailabilityGroup', 'ViewServerState', 'AlterAnyEndPoint', 'ConnectSql')
                }
                ServerPermission {
                    State      = 'GrantWithGrant'
                    Permission = @()
                }
                ServerPermission {
                    State      = 'Deny'
                    Permission = @()
                }
            )
            DependsOn    = '[SqlLogin]Add_WindowsUserClusSvc'
        }

        SqlPermission AddNTServiceClusSvcPermissions {
            InstanceName = $Node.SQLInstanceName
            Name         = 'NT SERVICE\ClusSvc'
            Permission   = @(
                ServerPermission {
                    State      = 'Grant'
                    Permission = @('AlterAnyAvailabilityGroup', 'ViewServerState', 'ConnectSql')
                }
                ServerPermission {
                    State      = 'GrantWithGrant'
                    Permission = @()
                }
                ServerPermission {
                    State      = 'Deny'
                    Permission = @()
                }
            )
            DependsOn    = '[SqlLogin]Add_WindowsUserClusSvc'
        }

        SqlRole Add_ServerRole_AdminSqlforBI {
            Ensure               = 'Present'
            ServerRoleName       = 'sysadmin'
            MembersToInclude     = $SQLSVCUserName
            InstanceName         = $Node.SQLInstanceName
            DependsOn            = '[SqlLogin]Add_WindowsUserSqlSvc'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        SqlEndpoint HADREndpoint {
            EndPointName         = 'HADR'
            EndpointType         = 'DatabaseMirroring'
            Port                 = 5022
            InstanceName         = $Node.SQLInstanceName
            DependsOn            = '[SqlRole]Add_ServerRole_AdminSqlforBI'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        SqlAlwaysOnService EnableHADR {
            Ensure               = 'Present'
            InstanceName         = $Node.SQLInstanceName
            DependsOn            = '[SqlEndpoint]HADREndpoint'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        SqlWaitForAG 'LAB2SQLAG' {
            Name                 = $Node.SQLAvailabilityGroupName
            ServerName           = 'LAB2SQL1'
            RetryIntervalSec     = 20
            RetryCount           = 30
            InstanceName         = $Node.SQLInstanceName
            DependsOn            = '[SqlAlwaysOnService]EnableHADR'
            PsDscRunAsCredential = $ActiveDirectoryAdministratorCredential
        }

        SqlAGReplica 'AddReplica' {
            Ensure                     = 'Present'
            Name                       = $Node.NodeName
            AvailabilityGroupName      = $Node.SQLAvailabilityGroupName
            ServerName                 = $Node.NodeName
            InstanceName               = $Node.SQLInstanceName
            PrimaryReplicaServerName   = 'LAB2SQL1'
            PrimaryReplicaInstanceName = 'MSSQLSERVER'
            FailoverMode               = 'Automatic'
            AvailabilityMode           = 'SynchronousCommit'
            DependsOn                  = '[SqlWaitForAG]LAB2SQLAG'
            PsDscRunAsCredential       = $ActiveDirectoryAdministratorCredential
        }

        SqlAGDatabase 'AddAGDatabaseMemberships' {
            AvailabilityGroupName = $Node.SQLAvailabilityGroupName
            BackupPath            = '\\LAB2SQLSOF\Backup_LAB2SQLAG'
            DatabaseName          = 'AdventureWorks'
            InstanceName          = 'MSSQLSERVER'
            ServerName            = 'LAB2SQL1'
            Ensure                = 'Present'

            PsDscRunAsCredential  = $ActiveDirectoryAdministratorCredential
            DependsOn             = '[SqlAGReplica]AddReplica'
        }
    }
}
