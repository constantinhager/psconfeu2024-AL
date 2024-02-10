<#
.SYNOPSIS
    This Script will deploy a SQL Server AG with the help of DSC.
.DESCRIPTION
    This Script will deploy a SQL Server AG with the help of DSC.

    The following VMs will be deployed:
    - Lab2DC
    - Lab2SQL1
    - Lab2SQL2

    Both VMs will be installed with SQL Server 2022 Enterpise Edition with DSC.
    A SQL Server AG (Always-On Availibility Group) will be deployed with DSC.
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
    HyperVProperties = @{ SwitchType = 'Internal'; AdapterName = 'vEthernet (NATSwitchLab2)' }
    AddressSpace     = '192.168.3.0/24'
}
Add-LabVirtualNetworkDefinition @splat

# Domain Controller
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab3' -UseDhcp -MacAddress '0017fb000005'
$splat = @{
    Name            = 'LAB3DC'
    OperatingSystem = 'Windows Server 2022 Datacenter'
    Processors      = 1
    Roles           = 'RootDC'
    NetworkAdapter  = $netAdapter
    Memory          = 2GB
}
Add-LabMachineDefinition @splat

# SQL Server 1
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab3' -UseDhcp -MacAddress '0017fb00000d'
Add-LabMachineDefinition -Name LAB3SQL1 -Processors 2 -NetworkAdapter $netAdapter -Roles SQLServer2022

# SQL Server 2
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab3' -UseDhcp -MacAddress '0017fb00000e'
Add-LabMachineDefinition -Name LAB3SQL2 -Processors 2 -NetworkAdapter $netAdapter -Roles SQLServer2022

Install-Lab

Show-LabDeploymentSummary
