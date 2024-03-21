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
$SecretFile = Import-PowerShellDataFile -Path E:\GIT\psconfeu2024-AL\.secrets.psd1
$ConfigData = Import-PowerShellDataFile -Path E:\GIT\psconfeu2024-AL\DSC\ConfigurationData.psd1

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
$splat = @{
    VirtualSwitch  = 'NATSwitchLab2'
    Ipv4Address    = '192.168.2.10'
    Ipv4Gateway    = '192.168.2.1'
    Ipv4DNSServers = '192.168.2.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
$splat = @{
    Name            = 'LAB2DC'
    OperatingSystem = 'Windows Server 2022 Datacenter'
    Processors      = 1
    NetworkAdapter  = $netAdapter
    Roles           = 'RootDC'
    Memory          = 2GB
}
Add-LabMachineDefinition @splat

# SQL Server 1
$splat = @{
    VirtualSwitch  = 'NATSwitchLab2'
    Ipv4Address    = '192.168.2.11'
    Ipv4Gateway    = '192.168.2.1'
    Ipv4DNSServers = '192.168.2.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
Add-LabDiskDefinition -Name Lab2SQL1DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab2SQL1DataDrive2 -DiskSizeInGb 100
$splat = @{
    Name                     = 'LAB2SQL1'
    Processors               = 2
    NetworkAdapter           = $netAdapter
    Roles                    = $roles
    DiskName                 = 'Lab2SQL1DataDrive1', 'Lab2SQL1DataDrive2'
    PostInstallationActivity = $PostInstallActivities
}
Add-LabMachineDefinition @splat

# SQL Server 2
$splat = @{
    VirtualSwitch  = 'NATSwitchLab2'
    Ipv4Address    = '192.168.2.12'
    Ipv4Gateway    = '192.168.2.1'
    Ipv4DNSServers = '192.168.2.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
Add-LabDiskDefinition -Name Lab2SQL2DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab2SQL2DataDrive2 -DiskSizeInGb 100
$splat = @{
    Name           = 'LAB2SQL2'
    Processors     = 2
    NetworkAdapter = $netAdapter
    Roles          = $roles
    DiskName       = 'Lab2SQL2DataDrive1', 'Lab2SQL2DataDrive2'
}
Add-LabMachineDefinition @splat

Install-Lab

# Download SQL Server 2022 current Cumulative Update
$splat = @{
    Uri  = 'https://download.microsoft.com/download/9/6/8/96819b0c-c8fb-4b44-91b5-c97015bbda9f/SQLServer2022-KB5032679-x64.exe'
    Path = "$labSources\SoftwarePackages\SQLServer2022-KB5032679-x64.exe"
}
Get-LabInternetFile @splat

# Download SQL Server SSMS
$Splat = @{
    Uri  = Get-PSFConfigValue -FullName 'AutomatedLab.Sql2022ManagementStudio'
    Path = "$labSources\SoftwarePackages\SSMS-Setup-ENU.exe"
}
Get-LabInternetFile @splat

# Download SQL Server AdventureWorks Sample Database
$Splat = @{
    Uri  = 'https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2022.bak'
    Path = "$labSources\SoftwarePackages\AdventureWorksLT2022.bak"
}
Get-LabInternetFile @splat


# Install PSDesiredStateConfiguration and ActiveDirectory DSC Resource
Install-Module -Name ActiveDirectoryDSC -Force -SkipPublisherCheck
Install-Module -Name DNSServerDSC -Force -SkipPublisherCheck
Install-Module -Name ComputerManagementDsc -Force -SkipPublisherCheck
Install-Module -Name FailoverClusterDSC -Force -SkipPublisherCheck

# LAB2DC
. E:\GIT\psconfeu2024-AL\DSC\LAB2DC\LAB2DC.ps1
$splat = @{
    TypeName     = 'System.Management.Automation.PSCredential'
    ArgumentList = "$($SecretFile.Lab2.DomainName)\$($SecretFile.Lab2.SQLSVCUserName)", (ConvertTo-SecureString -String $SecretFile.Lab2.SQLSvcPassword -AsPlainText -Force)
}
$SQLSVCCredential = New-Object @splat
Invoke-LabDscConfiguration -Configuration (Get-Command -Name LAB2DC) -ComputerName LAB2DC -ConfigurationData $ConfigData -Wait -Force -Parameter @{
    SQLSVCCredential = $SQLSVCCredential
}

# LAB2SQL1 Create Cluster
. E:\GIT\psconfeu2024-AL\DSC\LAB2SQL1\LAB2SQL1_CreateCluster.ps1

$splat = @{
    TypeName     = 'System.Management.Automation.PSCredential'
    ArgumentList = "$($SecretFile.Lab2.DomainName)\$($SecretFile.Lab2.DomainAdminCredentialUserName)", (ConvertTo-SecureString -String $SecretFile.Lab2.DomainAdminCredentialPassword -AsPlainText -Force)
}
$ActiveDirectoryAdministratorCredential = New-Object @splat

Invoke-LabDscConfiguration -Configuration (Get-Command -Name LAB2SQL1_CreateCluster) -ComputerName LAB2SQL1 -ConfigurationData $ConfigData -Wait -Force -Parameter @{
    ActiveDirectoryAdministratorCredential = $ActiveDirectoryAdministratorCredential
    ClusterName                            = $SecretFile.Lab2.ClusterName
    ClusterIPAddress                       = $SecretFile.Lab2.ClusterIPAddress
    StorageAccountName                     = $SecretFile.Lab2.witnessStorageAccountName
    StorageAccountAccessKey                = $SecretFile.Lab2.witnessStorageAccountKey
}

# LAB2SQL2 Join Cluster
. E:\GIT\psconfeu2024-AL\DSC\LAB2SQL2\LAB2SQL2_JoinCluster.ps1

$splat = @{
    TypeName     = 'System.Management.Automation.PSCredential'
    ArgumentList = "$($SecretFile.Lab2.DomainName)\$($SecretFile.Lab2.DomainAdminCredentialUserName)", (ConvertTo-SecureString -String $SecretFile.Lab2.DomainAdminCredentialPassword -AsPlainText -Force)
}
$ActiveDirectoryAdministratorCredential = New-Object @splat

Invoke-LabDscConfiguration -Configuration (Get-Command -Name LAB2SQL2_JoinCluster) -ComputerName LAB2SQL2 -ConfigurationData $ConfigData -Wait -Force -Parameter @{
    ActiveDirectoryAdministratorCredential = $ActiveDirectoryAdministratorCredential
    ClusterName                            = $SecretFile.Lab2.ClusterName
    ClusterIPAddress                       = $SecretFile.Lab2.ClusterIPAddress
}
