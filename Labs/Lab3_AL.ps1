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
$SqlRole = Get-LabMachineRoleDefinition -Role SQLServer2022 -Properties @{
    Features              = 'SQLEngine,Tools'
    SQLSvcAccount         = 'contoso\sqlsvc'
    SQLSvcPassword        = 'SomePass1'
    AgtSvcAccount         = 'contoso\sqlsvc'
    AgtSvcPassword        = 'SomePass1'
    AgtSvcStartupType     = 'Automatic'
    BrowserSvcStartupType = 'Automatic'
}
$roles = @()
$roles += $clusterRole
$roles += $SqlRole

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
    Name           = 'LAB3SQL1'
    Processors     = 2
    NetworkAdapter = $netAdapter
    Roles          = $roles
    DiskName       = 'Lab3SQL1DataDrive1', 'Lab3SQL1DataDrive2'
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
