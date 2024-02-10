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

$labName = 'LAB2'
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = 'NATSwitchLab2'
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'          = 2GB
    'Add-LabMachineDefinition:DomainName'      = 'contoso.com'
}

$splat = @{
    Name             = 'NATSwitchLab2'
    HyperVProperties = @{ SwitchType = 'Internal'; AdapterName = 'vEthernet (NATSwitchLab2)' }
    AddressSpace     = '192.168.2.0/24'
}
Add-LabVirtualNetworkDefinition @splat

# Domain Controller
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab2' -UseDhcp -MacAddress '0017fb000004'
$splat = @{
    Name            = 'LAB2DC'
    OperatingSystem = 'Windows Server 2022 Datacenter'
    Processors      = 1
    Roles           = 'RootDC'
    NetworkAdapter  = $netAdapter
    Memory          = 2GB
}
Add-LabMachineDefinition @splat

# SQL Server 1
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab2' -UseDhcp -MacAddress '0017fb00000b'
Add-LabMachineDefinition -Name LAB2SQL1 -Processors 2 -NetworkAdapter $netAdapter

# SQL Server 2
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab2' -UseDhcp -MacAddress '0017fb00000c'
Add-LabMachineDefinition -Name LAB2SQL2 -Processors 2 -NetworkAdapter $netAdapter

Install-Lab

Show-LabDeploymentSummary
