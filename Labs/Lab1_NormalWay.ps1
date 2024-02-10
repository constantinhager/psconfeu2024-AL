<#
.SYNOPSIS
    This Script will deploy a SQL Server AG in declerative fashion.
.DESCRIPTION
    This Script will deploy a SQL Server AG in declarative fashion.

    The following VMs will be deployed:
    - Lab1DC
    - Lab1SQL1
    - Lab1SQL2

    Both VMs will be installed with SQL Server 2022 Enterpise Edition with DBATools.
    A SQL Server AG (Always-On Availibility Group) will be deployed with DBATools.
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

$labName = 'LAB1'
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = 'NATSwitchLab1'
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'          = 2GB
    'Add-LabMachineDefinition:DomainName'      = 'contoso.com'
}

$splat = @{
    Name             = 'NATSwitchLab1'
    HyperVProperties = @{ SwitchType = 'Internal'; AdapterName = 'vEthernet (NATSwitchLab1)' }
    AddressSpace     = '192.168.1.0/24'
}
Add-LabVirtualNetworkDefinition @splat

# Domain Controller
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab1' -UseDhcp -MacAddress '0017fb000003'
$splat = @{
    Name            = 'LAB1DC'
    OperatingSystem = 'Windows Server 2022 Datacenter'
    Processors      = 1
    Roles           = 'RootDC'
    NetworkAdapter  = $netAdapter
    Memory          = 2GB
}
Add-LabMachineDefinition @splat

# SQL Server 1
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab1' -UseDhcp -MacAddress '0017fb000009'
Add-LabDiskDefinition -Name Lab1SQL1DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab1SQL1DataDrive2 -DiskSizeInGb 100
Add-LabMachineDefinition -Name LAB1SQL1 -Processors 2 -NetworkAdapter $netAdapter -DiskName "Lab1SQL1DataDrive1", "Lab1SQL1DataDrive2"

# SQL Server 2
$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitchLab1' -UseDhcp -MacAddress '0017fb00000a'
Add-LabDiskDefinition -Name Lab1SQL2DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab1SQL2DataDrive2 -DiskSizeInGb 100
Add-LabMachineDefinition -Name LAB1SQL2 -Processors 2 -NetworkAdapter $netAdapter -DiskName "Lab1SQL2DataDrive1", "Lab1SQL2DataDrive2"

Install-Lab

# Install Fail Over Cluster Role
Invoke-LabCommand -ComputerName LAB1SQL1,LAB1SQL2 -ActivityName "Install Failover Cluster Role" -ScriptBlock {
    Install-WindowsFeature -Name Failover-Clustering, FS-FileServer -IncludeManagementTools
}

# Prepare the disks
Invoke-LabCommand -ComputerName LAB1SQL1,LAB1SQL2 -ActivityName "Preparing Disks" -ScriptBlock {
    Get-Disk | Where-Object Number -NE $null | Where-Object IsBoot -NE $true | Where-Object IsSystem -NE $true | Where-Object PartitionStyle -NE RAW | ForEach-Object {
        $_ | Set-Disk -isoffline:$false
        $_ | Set-Disk -isreadonly:$false
        $_ | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
        $_ | Set-Disk -isreadonly:$true
        $_ | Set-Disk -isoffline:$true
    }
    Get-Disk | Where-Object Number -NE $Null | Where-Object IsBoot -NE $True | Where-Object IsSystem -NE $True | Where-Object PartitionStyle -EQ RAW | Group-Object -NoElement -Property FriendlyName
} -PassThru

# Run Cluster Validation
Invoke-LabCommand -ComputerName LAB1SQL1,LAB1SQL2 -ActivityName "Run Cluster Validation" -ScriptBlock {
    Test-Cluster -Node LAB1SQL1, LAB1SQL2 -Include 'Storage Spaces Direct', 'Inventory', 'Network', 'System Configuration'
} -PassThru

# Create dns entry for Cluster
Invoke-LabCommand -ComputerName LAB1DC -ActivityName "Create DNS Entry for Cluster" -ScriptBlock {
    Add-DnsServerResourceRecordA -Name LAB1SQLCL -ZoneName contoso.com -AllowUpdateAny -IPv4Address 192.168.1.200
} -PassThru

# Create the cluster
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName "Create Cluster" -ScriptBlock {
    New-Cluster -Name LAB1SQLCL -Node LAB1SQL1, LAB1SQL2 -StaticAddress 192.168.1.200 -NoStorage
} -PassThru

# Configure the cluster quorum as cloud witness
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName "Configure Cluster Quorum" -ScriptBlock {
    Set-ClusterQuorum -CloudWitness -AccountName lab1clwidness -AccessKey "<StorageAccountAccessKey>"
} -PassThru

# Enable storage spaces direct
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName "Enable Storage Spaces Direct" -ScriptBlock {
    Enable-ClusterStorageSpacesDirect
} -PassThru

# Generate Cluster volumes for Log, Data and Backup and SQL Install Sources
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName "Generate Cluster volumes" -ScriptBlock {
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLData -FileSystem CSVFS_ReFS -Size 20GB
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLLog -FileSystem CSVFS_ReFS -Size 20GB
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLBackup -FileSystem CSVFS_ReFS -Size 10GB
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLSources -FileSystem CSVFS_ReFS -Size 20GB
} -PassThru

# Create Scale-Out File Server
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName "Create Scale-Out File Server" -ScriptBlock {
    Add-ClusterScaleOutFileServerRole -Name LAB1SQLSOF -Cluster LAB1SQLCL
} -PassThru

Show-LabDeploymentSummary -Detailed
