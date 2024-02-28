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
$SecretFile = Import-PowerShellDataFile -Path E:\GIT\psconfeu2024-AL\.secrets.psd1
$witnessSAName = $SecretFile.Lab1.witnessStorageAccountName
$witnessSAAccessKey = $SecretFile.Lab1.witnessStorageAccountKey

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
$splat = @{
    VirtualSwitch  = 'NATSwitchLab1'
    Ipv4Address    = '192.168.1.10'
    Ipv4Gateway    = '192.168.1.1'
    Ipv4DNSServers = '192.168.1.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
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
$splat = @{
    VirtualSwitch  = 'NATSwitchLab1'
    Ipv4Address    = '192.168.1.11'
    Ipv4Gateway    = '192.168.1.1'
    Ipv4DNSServers = '192.168.1.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
Add-LabDiskDefinition -Name Lab1SQL1DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab1SQL1DataDrive2 -DiskSizeInGb 100
$splat = @{
    Name           = 'LAB1SQL1'
    Processors     = 2
    NetworkAdapter = $netAdapter
    DiskName       = 'Lab1SQL1DataDrive1', 'Lab1SQL1DataDrive2'
}
Add-LabMachineDefinition @splat

# SQL Server 2
$splat = @{
    VirtualSwitch  = 'NATSwitchLab1'
    Ipv4Address    = '192.168.1.12'
    Ipv4Gateway    = '192.168.1.1'
    Ipv4DNSServers = '192.168.1.10', '168.63.129.16'
}
$netAdapter = New-LabNetworkAdapterDefinition @splat
Add-LabDiskDefinition -Name Lab1SQL2DataDrive1 -DiskSizeInGb 100
Add-LabDiskDefinition -Name Lab1SQL2DataDrive2 -DiskSizeInGb 100
$splat = @{
    Name           = 'LAB1SQL2'
    Processors     = 2
    NetworkAdapter = $netAdapter
    DiskName       = 'Lab1SQL2DataDrive1', 'Lab1SQL2DataDrive2'
}
Add-LabMachineDefinition @splat

Install-Lab

# Wait for the PSRepository to be registered
Invoke-LabCommand -ComputerName LAB1SQL1, LAB1SQL2 -ActivityName 'Return Registered Repositories' -ScriptBlock {
    while ($null -eq (Get-PSRepository)) {
        Start-Sleep -Seconds 5
    }
} -PassThru

# Install PSResourceGet Module
Invoke-LabCommand -ComputerName LAB1SQL1, LAB1SQL2 -ActivityName 'Install PSResourceGet Module' -ScriptBlock {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
} -PassThru

# Install the dbatools module
Invoke-LabCommand -ComputerName LAB1SQL1, LAB1SQL2 -ActivityName 'Install dbatools Module' -ScriptBlock {
    Install-PSResource -Name dbatools -TrustRepository -Scope AllUsers
} -PassThru

# Install Fail Over Cluster and File Server Role
Invoke-LabCommand -ComputerName LAB1SQL1, LAB1SQL2 -ActivityName 'Install Failover Cluster and File Server Role' -ScriptBlock {
    Install-WindowsFeature -Name Failover-Clustering, FS-FileServer -IncludeManagementTools
}

# Prepare the disks
Invoke-LabCommand -ComputerName LAB1SQL1, LAB1SQL2 -ActivityName 'Preparing Disks' -ScriptBlock {
    Get-Disk | Where-Object Number -NE $null | Where-Object IsBoot -NE $true | Where-Object IsSystem -NE $true | Where-Object PartitionStyle -NE RAW | ForEach-Object {
        $_ | Set-Disk -IsOffline:$false
        $_ | Set-Disk -IsReadOnly:$false
        $_ | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
        $_ | Set-Disk -IsReadOnly:$true
        $_ | Set-Disk -IsOffline:$true
    }
    Get-Disk | Where-Object Number -NE $Null | Where-Object IsBoot -NE $True | Where-Object IsSystem -NE $True | Where-Object PartitionStyle -EQ RAW | Group-Object -NoElement -Property FriendlyName
} -PassThru

# Run Cluster Validation (Optional for lab environment)
#Invoke-LabCommand -ComputerName LAB1SQL1, LAB1SQL2 -ActivityName 'Run Cluster Validation' -ScriptBlock {
#Test-Cluster -Node LAB1SQL1, LAB1SQL2 -Include 'Storage Spaces Direct', 'Inventory', 'Network', 'System Configuration'
#} -PassThru

# Create dns entry for Cluster
Invoke-LabCommand -ComputerName LAB1DC -ActivityName 'Create DNS Entry for Cluster' -ScriptBlock {
    Add-DnsServerResourceRecordA -Name LAB1SQLCL -ZoneName contoso.com -AllowUpdateAny -IPv4Address 192.168.1.200
} -PassThru

# Create dns entry for AlwaysOn Listener
Invoke-LabCommand -ComputerName LAB1DC -ActivityName 'Create DNS Entry for AlwaysOn Listener' -ScriptBlock {
    Add-DnsServerResourceRecordA -Name LAB1SQLAG -ZoneName contoso.com -AllowUpdateAny -IPv4Address 192.168.1.201
} -PassThru

# Create SQL Server Engine Account
Invoke-LabCommand -ComputerName LAB1DC -ActivityName 'Create SQL Server Engine Account' -ScriptBlock {
    $Password = ConvertTo-SecureString -String 'SomePass1' -AsPlainText -Force
    New-ADUser -Name 'SQLSvc' -AccountPassword $Password -Enabled $true -PasswordNeverExpires $true
} -PassThru

# Create the cluster
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Create Cluster' -ScriptBlock {
    New-Cluster -Name LAB1SQLCL -Node LAB1SQL1, LAB1SQL2 -StaticAddress 192.168.1.200 -NoStorage
} -PassThru

# Configure the cluster quorum as cloud witness
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Configure Cluster Quorum' -ScriptBlock {
    Set-ClusterQuorum -CloudWitness -AccountName $witnessSAName -AccessKey $witnessSAAccessKey
} -PassThru -Variable (Get-Variable -Name witnessSAName), (Get-Variable -Name witnessSAAccessKey)

# Enable storage spaces direct
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Enable Storage Spaces Direct' -ScriptBlock {
    Enable-ClusterStorageSpacesDirect -Confirm:$false
} -PassThru

# Generate Cluster volumes for Log, Data and Backup and SQL Install Sources
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Generate Cluster volumes' -ScriptBlock {
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLData -FileSystem CSVFS_ReFS -Size 20GB
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLLog -FileSystem CSVFS_ReFS -Size 20GB
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLBackup -FileSystem CSVFS_ReFS -Size 10GB
    New-Volume -StoragePoolFriendlyName S2D* -FriendlyName SQLSources -FileSystem CSVFS_ReFS -Size 20GB
} -PassThru

# Create Scale-Out File Server
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Create Scale-Out File Server' -ScriptBlock {
    Add-ClusterScaleOutFileServerRole -Name LAB1SQLSOF -Cluster LAB1SQLCL
} -PassThru

# Create folders and shares
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Create Folders and Shares' -ScriptBlock {

    Move-ClusterGroup -Name 'LAB1SQLSOF' -Node LAB1SQL1

    New-Item -Path 'C:\ClusterStorage\SQLData\Shares\Data_LAB1SQL1' -ItemType Directory
    New-Item -Path 'C:\ClusterStorage\SQLData\Shares\Data_LAB1SQL2' -ItemType Directory
    New-Item -Path 'C:\ClusterStorage\SQLLog\Shares\Log_LAB1SQL1' -ItemType Directory
    New-Item -Path 'C:\ClusterStorage\SQLLog\Shares\Log_LAB1SQL2' -ItemType Directory
    New-Item -Path 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB1SQL1' -ItemType Directory
    New-Item -Path 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB1SQL2' -ItemType Directory
    New-Item -Path 'C:\ClusterStorage\SQLSources\Shares\Sources' -ItemType Directory
    New-SmbShare -Name Data_LAB1SQL1 -Path 'C:\ClusterStorage\SQLData\Shares\Data_LAB1SQL1' -FullAccess 'Everyone' -ScopeName LAB1SQLSOF
    New-SmbShare -Name Data_LAB1SQL2 -Path 'C:\ClusterStorage\SQLData\Shares\Data_LAB1SQL2' -FullAccess 'Everyone' -ScopeName LAB1SQLSOF
    New-SmbShare -Name Log_LAB1SQL1 -Path 'C:\ClusterStorage\SQLLog\Shares\Log_LAB1SQL1' -FullAccess 'Everyone' -ScopeName LAB1SQLSOF
    New-SmbShare -Name Log_LAB1SQL2 -Path 'C:\ClusterStorage\SQLLog\Shares\Log_LAB1SQL2' -FullAccess 'Everyone' -ScopeName LAB1SQLSOF
    New-SmbShare -Name Backup_LAB1SQL1 -Path 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB1SQL1' -FullAccess 'Everyone' -ScopeName LAB1SQLSOF
    New-SmbShare -Name Backup_LAB1SQL2 -Path 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB1SQL2' -FullAccess 'Everyone' -ScopeName LAB1SQLSOF
    New-SmbShare -Name SQLSources -Path 'C:\ClusterStorage\SQLSources\Shares\Sources' -FullAccess 'Everyone' -ScopeName LAB1SQLSOF
} -PassThru

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

# Copy SQL Server 2022 CU SQLSources share
$splat = @{
    ComputerName          = 'LAB1SQL1'
    Path                  = "$labSources\SoftwarePackages\SQLServer2022-KB5032679-x64.exe"
    DestinationFolderPath = 'C:\ClusterStorage\SQLSources\Shares\Sources'
    PassThru              = $true
}
Copy-LabFileItem @splat

# Copy SQL Server 2022 SSMS into the SQLSources share
$splat = @{
    ComputerName          = 'LAB1SQL1'
    Path                  = "$labSources\SoftwarePackages\SSMS-Setup-ENU.exe"
    DestinationFolderPath = 'C:\ClusterStorage\SQLSources\Shares\Sources'
    PassThru              = $true
}
Copy-LabFileItem @splat

# Copy Adventure Works database into the SQLSources share
$splat = @{
    ComputerName          = 'LAB1SQL1'
    Path                  = "$labSources\SoftwarePackages\AdventureWorksLT2022.bak"
    DestinationFolderPath = 'C:\ClusterStorage\SQLSources\Shares\Sources'
    PassThru              = $true
}
Copy-LabFileItem @splat

# restart LAB1SQL1, LAB1SQL2
Write-ScreenInfo -Message 'Restarting LAB1SQL1 and LAB1SQL2 before installing Microsoft SQL Server' -TaskStart
Restart-LabVM -ComputerName LAB1SQL1, LAB1SQL2 -Wait -ProgressIndicator 5 -NoNewLine
Write-ScreenInfo -Message 'Sucessfully restarted LAB1SQL1 and LAB1SQL2' -TaskEnd

# Mount sql server 2022 iso on LAB1SQL1
$Info = Mount-LabIsoImage -ComputerName LAB1SQL1 -IsoPath "$labSources\ISOs\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso" -PassThru
$DriveLetter = $Info.DriveLetter

# Install SQL Server 2022 on LAB1SQL1
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Install SQL Server 2022' -Variable (Get-Variable -Name DriveLetter) -ScriptBlock {

    $EngineCredential = New-Object System.Management.Automation.PSCredential ('contoso\SQLSvc', (ConvertTo-SecureString 'SomePass1' -AsPlainText -Force))
    $AgentCredential = New-Object System.Management.Automation.PSCredential ('contoso\SQLSvc', (ConvertTo-SecureString 'SomePass1' -AsPlainText -Force))
    $AdminCredential = New-Object System.Management.Automation.PSCredential ('contoso\Administrator', (ConvertTo-SecureString 'Somepass1' -AsPlainText -Force))

    $config = @{
        BROWSERSVCSTARTUPTYPE = 'Automatic'
    }

    $Splat = @{
        SQLInstance      = 'LAB1SQL1'
        Version          = '2022'
        Feature          = 'Engine'
        Path             = "$DriveLetter\"
        UpdateSourcePath = '\\LAB1SQLSOF\SQLSources'
        Confirm          = $false
        DataPath         = '\\LAB1SQLSOF\Data_LAB1SQL1'
        LogPath          = '\\LAB1SQLSOF\Log_LAB1SQL1'
        BackupPath       = '\\LAB1SQLSOF\Backup_LAB1SQL1'
        Configuration    = $config
        EngineCredential = $EngineCredential
        AgentCredential  = $AgentCredential
        Authentication   = 'Credssp'
        Credential       = $AdminCredential
    }
    $InstallResult = Install-DbaInstance @Splat
    $InstallResult | Format-List *
} -PassThru

# Install SSMS on LAB1SQL1
$Splat = @{
    LocalPath    = 'C:\ClusterStorage\SQLSources\Shares\Sources\SSMS-Setup-ENU.exe'
    CommandLine  = '/install /passive /quiet /norestart'
    ComputerName = 'LAB1SQL1'
    PassThru     = $true
}
Install-LabSoftwarePackage @Splat

# Dismout sql server 2022 iso on LAB1SQL1
Dismount-LabIsoImage -ComputerName LAB1SQL1

# Restart LAB1SQL1
Write-ScreenInfo -Message 'Restarting LAB1SQL1' -TaskStart
Restart-LabVM -ComputerName LAB1SQL1 -Wait -ProgressIndicator 5
Write-ScreenInfo -Message 'Sucessfully restarted LAB1SQL1' -TaskEnd

# Check if every SQL Server service is running on LAB1SQL1.
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Check if every SQL Server service is running. If not wait until they are started.' -ScriptBlock {
    $services = Get-Service -Name '*SQL*'
    foreach ($service in $services) {
        $service.WaitForStatus('Running')
    }
} -PassThru

# Enable AlwaysOn Availability Groups on LAB1SQL1
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Enable AlwaysOn Availability Groups' -ScriptBlock {
    Enable-DbaAgHadr -SqlInstance LAB1SQL1 -Force
} -PassThru

# Mount sql server 2022 iso on LAB1SQL2
$Info = Mount-LabIsoImage -ComputerName LAB1SQL2 -IsoPath "$labSources\ISOs\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso" -PassThru
$DriveLetter = $Info.DriveLetter

# Install SQL Server 2022 on LAB1SQL2
Invoke-LabCommand -ComputerName LAB1SQL2 -ActivityName 'Install SQL Server 2022' -Variable (Get-Variable -Name DriveLetter) -ScriptBlock {

    $EngineCredential = New-Object System.Management.Automation.PSCredential ('contoso\SQLSvc', (ConvertTo-SecureString 'SomePass1' -AsPlainText -Force))
    $AgentCredential = New-Object System.Management.Automation.PSCredential ('contoso\SQLSvc', (ConvertTo-SecureString 'SomePass1' -AsPlainText -Force))
    $AdminCredential = New-Object System.Management.Automation.PSCredential ('contoso\Administrator', (ConvertTo-SecureString 'Somepass1' -AsPlainText -Force))

    $config = @{
        BROWSERSVCSTARTUPTYPE = 'Automatic'
    }

    $Splat = @{
        SQLInstance      = 'LAB1SQL2'
        Version          = '2022'
        Feature          = 'Engine'
        Path             = "$DriveLetter\"
        UpdateSourcePath = '\\LAB1SQLSOF\SQLSources'
        Confirm          = $false
        DataPath         = '\\LAB1SQLSOF\Data_LAB1SQL2'
        LogPath          = '\\LAB1SQLSOF\Log_LAB1SQL2'
        BackupPath       = '\\LAB1SQLSOF\Backup_LAB1SQL2'
        Configuration    = $config
        EngineCredential = $EngineCredential
        AgentCredential  = $AgentCredential
        Authentication   = 'Credssp'
        Credential       = $AdminCredential
    }
    $InstallResult = Install-DbaInstance @Splat
    $InstallResult | Format-List *
} -PassThru

# Install SSMS on LAB1SQL2
$Splat = @{
    LocalPath    = 'C:\ClusterStorage\SQLSources\Shares\Sources\SSMS-Setup-ENU.exe'
    CommandLine  = '/install /passive /quiet /norestart'
    ComputerName = 'LAB1SQL2'
    PassThru     = $true
}
Install-LabSoftwarePackage @Splat

# Dismout sql server 2022 iso on LAB1SQL2
Dismount-LabIsoImage -ComputerName LAB1SQL2

# Restart LAB1SQL2
Write-ScreenInfo -Message 'Restarting LAB1SQL2' -TaskStart
Restart-LabVM -ComputerName LAB1SQL2 -Wait -ProgressIndicator 5
Write-ScreenInfo -Message 'Sucessfully restarted LAB1SQL2' -TaskEnd

# Check if every SQL Server service is running on LAB1SQL2.
Invoke-LabCommand -ComputerName LAB1SQL2 -ActivityName 'Check if every SQL Server service is running. If not wait until they are started.' -ScriptBlock {
    $services = Get-Service -Name '*SQL*'
    foreach ($service in $services) {
        $service.WaitForStatus('Running')
    }
} -PassThru

# Enable AlwaysOn Availability Groups on LAB1SQL2
Invoke-LabCommand -ComputerName LAB1SQL2 -ActivityName 'Enable AlwaysOn Availability Groups' -ScriptBlock {
    Enable-DbaAgHadr -SqlInstance LAB1SQL2 -Force
} -PassThru

# Revert the SQL Security settings
Invoke-LabCommand -ComputerName LAB1SQL1, LAB1SQL2 -ActivityName 'Revert SQL Security Settings' -ScriptBlock {
    Set-DbatoolsInsecureConnection
} -PassThru

# Restore AdventureWorksLT2022 on LAB1SQL1
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Restore AdventureWorksLT2022' -ScriptBlock {
    Restore-DbaDatabase -SqlInstance LAB1SQL1 -Path '\\LAB1SQLSOF\SQLSources\AdventureWorksLT2022.bak' -DatabaseName 'AdventureWorksLT2022'
} -PassThru

# Change recovery model to full on AdventureWorksLT2022 on LAB1SQL1
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Change Recovery Model to Full on AdventureWorksLT2022' -ScriptBlock {
    Set-DbaDbRecoveryModel -SqlInstance LAB1SQL1 -Database AdventureWorksLT2022 -RecoveryModel Full -Confirm:$false
} -PassThru

# Setup AlwaysOn Availability Group endpoint on LAB1SQL1
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Setup AlwaysOn Availability Group Endpoint' -ScriptBlock {
    $Splat = @{
        SqlInstance = 'LAB1SQL1'
        Name        = 'hadr_endpoint'
        Port        = 5022
    }
    New-DbaEndpoint @Splat | Start-DbaEndpoint | Format-Table
    New-DbaLogin -SqlInstance LAB1SQL1 -Login 'contoso\SQLSvc' | Format-Table
    Invoke-DbaQuery -SqlInstance LAB1SQL1 -Query 'GRANT CONNECT ON ENDPOINT::hadr_endpoint TO [contoso\SQLSvc]'
} -PassThru

# Setup AlwaysOn Availability Group endpoint on LAB1SQL2
Invoke-LabCommand -ComputerName LAB1SQL2 -ActivityName 'Setup AlwaysOn Availability Group Endpoint' -ScriptBlock {
    $Splat = @{
        SqlInstance = 'LAB1SQL2'
        Name        = 'hadr_endpoint'
        Port        = 5022
    }
    New-DbaEndpoint @Splat | Start-DbaEndpoint | Format-Table
    New-DbaLogin -SqlInstance LAB1SQL2 -Login 'contoso\SQLSvc' | Format-Table
    Invoke-DbaQuery -SqlInstance LAB1SQL2 -Query 'GRANT CONNECT ON ENDPOINT::hadr_endpoint TO [contoso\SQLSvc]'
} -PassThru

# Backup database AdventureWorksLT2022 on LAB1SQL1 and restore on LAB1SQL2
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Backup AdventureWorksLT2022' -ScriptBlock {
    $splat = @{
        SqlInstance = 'LAB1SQL1'
        Database    = 'AdventureWorksLT2022'
        Path        = '\\LAB1SQLSOF\Backup_LAB1SQL1\'
        Type        = 'Database'
    }
    Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance LAB1SQL2 -NoRecovery

    $splat = @{
        SqlInstance = 'LAB1SQL1'
        Database    = 'AdventureWorksLT2022'
        Path        = '\\LAB1SQLSOF\Backup_LAB1SQL1\'
        Type        = 'Log'
    }
    Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance LAB1SQL2 -Continue -NoRecovery
} -PassThru

# Create AlwaysOn Availability Group on LAB1SQL1
Invoke-LabCommand -ComputerName LAB1SQL1 -ActivityName 'Create AlwaysOn Availability Group' -ScriptBlock {
    $Splat = @{
        Name        = 'LAB1SQLAG'
        Database    = 'AdventureWorksLT2022'
        ClusterType = 'Wsfc'
        Primary     = 'LAB1SQL1'
        Secondary   = 'LAB1SQL2'
        SeedingMode = 'Automatic'
        IpAddress   = '192.168.1.201'
        Confirm     = $false
    }
    $AG = New-DbaAvailabilityGroup @Splat
    $AG | Format-List *
} -PassThru

Show-LabDeploymentSummary -Detailed
