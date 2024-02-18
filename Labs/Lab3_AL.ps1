<#
.SYNOPSIS
    This Script will deploy a SQL Server AG in fully AL Fashion.
.DESCRIPTION
    This Script will deploy a SQL Server AG in fully AL Fashion.

    The following VMs will be deployed:
    - Lab3DC
    - Lab3SQL1
    - Lab3SQL2

    Both VMs will be installed with SQL Server 2022 Enterpise Edition with AL.
    A SQL Server AG (Always-On Availibility Group) will be deployed with AL.

    The full sql server feature command line documentation can be found here:
    https://learn.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-ver16#Feature
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

$labName = 'LAB3'
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

Add-LabIsoImageDefinition -Name SQLServer2022 -Path $labSources\ISOs\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = 'NATSwitchLab3'
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'          = 2GB
    'Add-LabMachineDefinition:DomainName'      = 'contoso.com'
}

$VolumeDefinitions = New-Object 'System.Collections.Generic.List[System.Object]'

$SQLData = [PSCustomObject]@{
    FriendlyName       = 'SQLData'
    Size               = 20GB # 20GB but do not write 20GB because it won't work
    FileSystem         = 'CSVFS_ReFS'
    AllocationUnitSize = 65536
}

$SQLLog = [PSCustomObject]@{
    FriendlyName       = 'SQLLog'
    Size               = 20GB # 20GB but do not write 20GB because it won't work
    FileSystem         = 'CSVFS_ReFS'
    AllocationUnitSize = 65536
}

$SQLBackup = [PSCustomObject]@{
    FriendlyName       = 'SQLBackup'
    Size               = 10GB # 10GB but do not write 10GB because it won't work
    FileSystem         = 'CSVFS_ReFS'
    AllocationUnitSize = 65536
}

$SQLSources = [PSCustomObject]@{
    FriendlyName       = 'SQLSources'
    Size               = 20GB # 20GB but do not write 20GB because it won't work
    FileSystem         = 'CSVFS_ReFS'
    AllocationUnitSize = 4096
}

$VolumeDefinitions.Add($SQLData)
$VolumeDefinitions.Add($SQLLog)
$VolumeDefinitions.Add($SQLBackup)
$VolumeDefinitions.Add($SQLSources)

$ClusterFolderAndShareDefinition = New-Object 'System.Collections.Generic.List[System.Object]'

$Data_LAB3SQL1 = [PSCustomObject]@{
    Name       = 'Data_LAB3SQL1'
    Path       = 'C:\ClusterStorage\SQLData\Shares\Data_LAB3SQL1'
    FullAccess = 'Everyone'
}

$Data_LAB3SQL2 = [PSCustomObject]@{
    Name       = 'Data_LAB3SQL2'
    Path       = 'C:\ClusterStorage\SQLData\Shares\Data_LAB3SQL2'
    FullAccess = 'Everyone'
}

$Log_LAB3SQL1 = [PSCustomObject]@{
    Name       = 'Log_LAB3SQL1'
    Path       = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB3SQL1'
    FullAccess = 'Everyone'
}

$Log_LAB3SQL2 = [PSCustomObject]@{
    Name       = 'Log_LAB3SQL2'
    Path       = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB3SQL2'
    FullAccess = 'Everyone'
}

$Backup_LAB3SQL1 = [PSCustomObject]@{
    Name       = 'Backup_LAB3SQL1'
    Path       = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB3SQL1'
    FullAccess = 'Everyone'
}

$Backup_LAB3SQL2 = [PSCustomObject]@{
    Name       = 'Backup_LAB3SQL2'
    Path       = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB3SQL2'
    FullAccess = 'Everyone'
}

$SQLSources = [PSCustomObject]@{
    Name       = 'SQLSources'
    Path       = 'C:\ClusterStorage\SQLSources\Shares\Sources'
    FullAccess = 'Everyone'
}

$ClusterFolderAndShareDefinition.Add($Data_LAB3SQL1)
$ClusterFolderAndShareDefinition.Add($Data_LAB3SQL2)
$ClusterFolderAndShareDefinition.Add($Log_LAB3SQL1)
$ClusterFolderAndShareDefinition.Add($Log_LAB3SQL2)
$ClusterFolderAndShareDefinition.Add($Backup_LAB3SQL1)
$ClusterFolderAndShareDefinition.Add($Backup_LAB3SQL2)
$ClusterFolderAndShareDefinition.Add($SQLSources)

$splat = @{
    Name             = 'NATSwitchLab3'
    HyperVProperties = @{ SwitchType = 'Internal'; AdapterName = 'vEthernet (NATSwitchLab3)' }
    AddressSpace     = '192.168.3.0/24'
}
Add-LabVirtualNetworkDefinition @splat

# Domain Controller
#$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab3' -UseDhcp -MacAddress '0017fb000005'
$splat = @{
    VirtualSwitch  = 'NATSwitchLab3'
    Ipv4Address    = '192.168.3.10'
    Ipv4Gateway    = '192.168.3.1'
    Ipv4DNSServers = '192.168.3.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat

$splat = @{
    Name            = 'LAB3DC'
    OperatingSystem = 'Windows Server 2022 Datacenter'
    Processors      = 1
    Roles           = 'RootDC'
    NetworkAdapter  = $netAdapter
    Memory          = 2GB
}
Add-LabMachineDefinition @splat


# Configure AL Cluster Role
$clusterRole = Get-LabMachineRoleDefinition -Role FailoverNode -Properties @{
    ClusterName = 'LAB3SQLCL'
    ClusterIP   = '192.168.3.200'
}
#$SqlRole = Get-LabMachineRoleDefinition -Role SQLServer2022 -Properties @{
#    Features              = 'SQLEngine,Tools'
#    SQLSvcAccount         = 'contoso\sqlsvc'
#    SQLSvcPassword        = 'SomePass1'
#    AgtSvcAccount         = 'contoso\sqlsvc'
#    AgtSvcPassword        = 'SomePass1'
#    AgtSvcStartupType     = 'Automatic'
#    BrowserSvcStartupType = 'Automatic'
#}
$roles = @()
$roles += $clusterRole
#$roles += $SqlRole

# Post Installation Activities
$PostInstallActivities = @()
#$PResourceGet = Get-LabPostInstallationActivity -CustomRole InstallPSResourceGet
#$DBATools = Get-LabPostInstallationActivity -CustomRole InstallDBATools
#$SQLCU = Get-LabPostInstallationActivity -CustomRole InstallSQLServerCU -Properties @{
#    KBUri  = 'https://download.microsoft.com/download/9/6/8/96819b0c-c8fb-4b44-91b5-c97015bbda9f/SQLServer2022-KB5032679-x64.exe'
#    KBName = 'SQLServer2022-KB5032679-x64.exe'
#}
$PrepareDisksForS2D = Get-LabPostInstallationActivity -CustomRole PrepareDisksForS2D
$ClusterCloudWitness = Get-LabPostInstallationActivity -CustomRole InstallClusterCloudWitness -Properties @{
    StorageAccountName = 'lab3clwitness'
    AccessKey          = '/lRB+GKZ9KrBTX/aLRJCSX4P403aUoGiaJ4T69q2ZXA0aJ1SjnXkZZPhVB2/+CubsDey31EfaP+F+AStLjYVEw=='
}
$EnableS2D = Get-LabPostInstallationActivity -CustomRole EnableS2D
$ClusterVolumes = Get-LabPostInstallationActivity -CustomRole InstallClusterVolumes -Properties @{
    VolumeDefinition = $VolumeDefinitions
}
$ScaleOutFileServer = Get-LabPostInstallationActivity -CustomRole InstallScaleOutFileServer -Properties @{
    SOFSName    = 'LAB3SQLSOF'
    ClusterName = 'LAB3SQLCL'
}
$FoldersAndShares = Get-LabPostInstallationActivity -CustomRole InstallScaleOutFileServerClusterFoldersAndShares -Properties @{
    SOFSName                        = 'LAB3SQLSOF'
    ClusterFolderAndShareDefinition = $ClusterFolderAndShareDefinition
}
#$RestoreSampleDatabase = Get-LabPostInstallationActivity -CustomRole RestoreSampleDatabase -Properties @{
#    DestinationFolderPath = '\\LAB3SQLSOF\Sources'
#}
#$PrepareSampleDatabaseForAG = Get-LabPostInstallationActivity -CustomRole PrepareSampleDatabaseForAG -Properties @{
#    BackupPath = '\\LAB3SQLSOF\Backup_LAB3SQL1\'
#}
#$CreateAG = Get-LabPostInstallationActivity -CustomRole CreateAlwaysOnAvailabilityGroup -Properties @{
#    AGName               = 'LAB3SQLAG'
#    AGDatabase           = 'AdventureWorksLT2022'
#    AGIPAddress          = '192.168.3.201'
#    SQLEngineAccountName = 'contoso\sqlsvc'
#}

#$PostInstallActivities += $PResourceGet
#$PostInstallActivities += $DBATools
#$PostInstallActivities += $SQLCU
$PostInstallActivities += $PrepareDisksForS2D
$PostInstallActivities += $ClusterCloudWitness
$PostInstallActivities += $EnableS2D
$PostInstallActivities += $ClusterVolumes
$PostInstallActivities += $ScaleOutFileServer
$PostInstallActivities += $FoldersAndShares
#$PostInstallActivities += $RestoreSampleDatabase
#$PostInstallActivities += $PrepareSampleDatabaseForAG
#$PostInstallActivities += $CreateAG

# SQL Server 1, Failover Cluster Node
$splat = @{
    VirtualSwitch  = 'NATSwitchLab3'
    Ipv4Address    = '192.168.3.11'
    Ipv4Gateway    = '192.168.3.1'
    Ipv4DNSServers = '192.168.3.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
Add-LabDiskDefinition -Name Lab3SQL1DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab3SQL1DataDrive2 -DiskSizeInGb 100
$splat = @{
    Name                     = 'LAB3SQL1'
    Processors               = 2
    NetworkAdapter           = $netAdapter
    Roles                    = $roles
    DiskName                 = 'Lab3SQL1DataDrive1', 'Lab3SQL1DataDrive2'
    PostInstallationActivity = $PostInstallActivities
}
Add-LabMachineDefinition @splat

# SQL Server 2, Failover Cluster Node
$splat = @{
    VirtualSwitch  = 'NATSwitchLab3'
    Ipv4Address    = '192.168.3.12'
    Ipv4Gateway    = '192.168.3.1'
    Ipv4DNSServers = '192.168.3.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
Add-LabDiskDefinition -Name Lab3SQL2DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab3SQL2DataDrive2 -DiskSizeInGb 100
$splat = @{
    Name           = 'LAB3SQL2'
    Processors     = 2
    NetworkAdapter = $netAdapter
    Roles          = $roles
    DiskName       = 'Lab3SQL2DataDrive1', 'Lab3SQL2DataDrive2'
}
Add-LabMachineDefinition @splat

Install-Lab

Show-LabDeploymentSummary -Detailed
