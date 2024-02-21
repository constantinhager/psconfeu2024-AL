param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $AGName,

    [Parameter(Mandatory)]
    [string[]]
    $AGDatabase,

    [Parameter(Mandatory)]
    [string]
    $AGIPAddress,

    [Parameter()]
    [string]
    $AGPort = 5022,

    [Parameter(Mandatory)]
    [string]
    $SQLEngineAccountName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLServerVM = Get-LabVM -ComputerName $ComputerName
$SQLInstanceName = $SQLServerVM.Roles.Properties.InstanceName

$DCName = (Get-LabVM -Role RootDC | Select-Object -First 1).Name
$DomainName = (Get-LabDomainDefinition).Name
$AllSQLServers = Get-LabVM | Where-Object { $_.Roles.Name -like 'SQL*' -and $_.Roles.Name -eq 'FailOverNode' } | Select-Object -ExpandProperty Name
$AGNodeNames = Get-LabVM | Where-Object { $_.Roles.Name -like 'SQL*' -and $_.Roles.Name -eq 'FailOverNode' } | Select-Object -ExpandProperty Name

if(-not([string]::IsNullOrEmpty($SQLInstanceName))) {
    $AllSQLServers = $AllSQLServers.ForEach({ "$_\$SQLInstance" })
}

Invoke-LabCommand -ComputerName $DCName -ActivityName "Create DNS Entry for AlwaysOn Listener on Domain Controller $DCName" -ScriptBlock {
    Add-DnsServerResourceRecordA -Name $AGName -ZoneName $DomainName -AllowUpdateAny -IPv4Address $AGIPAddress
} -PassThru -Variable (Get-Variable -Name AGName), (Get-Variable -Name AGIPAddress), (Get-Variable -Name DomainName)

Invoke-LabCommand -ComputerName $AGNodeNames -ActivityName "Enable AlwaysOn Availability Groups on $($AllSQLServers -join ", " )" -ScriptBlock {
    Enable-DbaAgHadr -SqlInstance $AllSQLServers -Force
} -PassThru -Variable (Get-Variable -Name AllSQLServers), (Get-Variable -Name SQLInstance)

foreach($SQLServer in $AGNodeNames) {
    Invoke-LabCommand -ComputerName $SQLServer -ActivityName "Setup AlwaysOn Availability Group Endpoint on $SQLServer" -ScriptBlock {
        if (-not ($SQLInstance.ToUpper() -eq 'MSSQLSERVER')) {
            $SQLServer = [string]::Concat($SQLServer, '\', $SQLInstance)
        }

        $Splat = @{
            SqlInstance = $SQLServer
            Name        = 'hadr_endpoint'
            Port        = $AGPort
        }
        New-DbaEndpoint @Splat | Start-DbaEndpoint | Format-Table
        New-DbaLogin -SqlInstance $SQLServer -Login $SQLEngineAccountName | Format-Table
        Invoke-DbaQuery -SqlInstance $SQLServer -Query "GRANT CONNECT ON ENDPOINT::hadr_endpoint TO [$SQLEngineAccountName]"
    } -PassThru (Get-Variable -Name SQLServer), (Get-Variable -Name AGPort), (Get-Variable -Name SQLEngineAccountName), (Get-Variable -Name SQLInstance)
}

Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Create AlwaysOn Availability Group' -ScriptBlock {
    $Splat = @{
        Name        = $AGName
        Database    = $AGDatabase
        ClusterType = 'Wsfc'
        Primary     = $AGNodeNames[0]
        Secondary   = $AGNodeNames[1]
        SeedingMode = 'Automatic'
        IpAddress   = $AGIPAddress
        Confirm     = $false
    }
    $AG = New-DbaAvailabilityGroup @Splat
    $AG | Format-List *
} -PassThru -Variable (Get-Variable -Name AGName),
(Get-Variable -Name AGNodeNames),
(Get-Variable -Name AGIPAddress),
(Get-Variable -Name AGDatabase)
