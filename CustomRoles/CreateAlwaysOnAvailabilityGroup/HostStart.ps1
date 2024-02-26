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


function New-LabAvailabilityGroup {

    <#
.SYNOPSIS
    Creates a new AlwaysOn Availability Group on a specified computer.

.DESCRIPTION
    The New-LabAvailabilityGroup function creates a new AlwaysOn Availability Group on the specified computer.
    It provides a custom message if the primary and secondary servers are inside of a named instance.

.PARAMETER ComputerName
    The name of the computer where AutomatedLab will start the creation of the Avalability group from.
    Defaults to the name of the LabVM.

.PARAMETER AGName
    The name of the availability group.

.PARAMETER AGDatabase
    An array of database names to include in the availability group.

.PARAMETER Primary
    The name of the primary server for the availability group.

.PARAMETER Secondary
    The name of the secondary server for the availability group.

.PARAMETER AGIpAddress
    The IP address for the availability group.

.EXAMPLE
    Case: The primary and secondary servers are inside of a named instance.
    $Splat = @{
        ComputerName = "LAB3SQL1"
        AGName       = "LAB3SQLAG"
        AGDatabase   = "AdventureWorksLT2022"
        Primary      = "LAB3SQL1\SQLAG"
        Secondary    = "LAB3SQL2\SQLAG"
        AGIpAddress  = "192.168.3.201"
    }
    New-LabAvailabilityGroup @Splat

    This example creates a new availability group named "LAB3SQLAG" on "LAB3SQL1" with the database AdventureWorksLT2022.
    The primary server is "LAB3SQL1\SQLAG" and the secondary server is "LAB3SQL2\SQLAG". The availability group IP address is "192.168.3.201".

.EXAMPLE
    Case: The primary and secondary servers are inside of a default instance.
    $splat = @{
        ComputerName = "LAB3SQL1"
        AGName       = "LAB3SQLAG"
        AGDatabase   = "AdventureWorksLT2022"
        Primary      = "LAB3SQL1"
        Secondary    = "LAB3SQL2"
        AGIpAddress  = "192.168.3.201"
    }
    New-LabAvailabilityGroup @splat

    This example creates a new availability group named "LAB3SQLAG" on "LAB3SQL1" with the database AdventureWorksLT2022.
    The primary server is "LAB3SQL1" and the secondary server is "LAB3SQL2". The availability group IP address is "192.168.3.201".

#>
    [CmdletBinding()]
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
        $Primary,

        [Parameter(Mandatory)]
        [string]
        $Secondary,

        [Parameter(Mandatory)]
        [string]
        $AGIpAddress
    )

    if ($Primary.Contains('\') -or $Secondary.Contains('\')) {
        $ActivityName = "Create AlwaysOn Availability Group $AGName on $ComputerName inside of a named instance"
    } else {
        $ActivityName = "Create AlwaysOn Availability Group $AGName on $ComputerName inside of a default instance"
    }

    Invoke-LabCommand -ComputerName $ComputerName -ActivityName $ActivityName -ScriptBlock {
        $Splat = @{
            Name        = $AGName
            Database    = $AGDatabase
            ClusterType = 'Wsfc'
            Primary     = $Primary
            Secondary   = $Secondary
            SeedingMode = 'Automatic'
            IpAddress   = $AGIPAddress
            Confirm     = $false
        }
        $AG = New-DbaAvailabilityGroup @Splat
        $AG | Format-List *
    } -PassThru -Variable (Get-Variable -Name AGName),
(Get-Variable -Name Primary),
(Get-Variable -Name Secondary),
(Get-Variable -Name AGIPAddress),
(Get-Variable -Name AGDatabase)
}

$SQLServerVM = Get-LabVM -ComputerName $ComputerName
$SQLInstanceName = $SQLServerVM.Roles.Properties.InstanceName
$AGNodeNamesWithInstanceName = $null

$DCName = (Get-LabVM -Role RootDC | Select-Object -First 1).Name
$DomainName = (Get-LabDomainDefinition).Name
$AGNodeNames = (Get-LabVM | Where-Object { $_.Roles.Name -like 'SQL*' -and $_.Roles.Name -eq 'FailOverNode' }).Name

if (-not([string]::IsNullOrEmpty($SQLInstanceName))) {
    $AGNodeNamesWithInstanceName = $AGNodeNames.ForEach({ "$_\$SQLInstanceName" })
}

Invoke-LabCommand -ComputerName $DCName -ActivityName "Create DNS Entry for AlwaysOn Listener on Domain Controller $DCName" -ScriptBlock {
    Add-DnsServerResourceRecordA -Name $AGName -ZoneName $DomainName -AllowUpdateAny -IPv4Address $AGIPAddress
} -PassThru -Variable (Get-Variable -Name AGName), (Get-Variable -Name AGIPAddress), (Get-Variable -Name DomainName)

foreach ($SQLServer in $AGNodeNames) {

    Invoke-LabCommand -ComputerName $SQLServer -ActivityName "Enable AlwaysOn Availability Groups on $SQLServer" -ScriptBlock {
        if ([string]::IsNullOrEmpty($SQLInstanceName)) {
            $SQLInstance = $SQLServer
        } else {
            $SQLInstance = [string]::Concat($SQLServer, '\', $SQLInstanceName)
        }

        Enable-DbaAgHadr -SqlInstance $SQLInstance -Force
    } -PassThru -Variable (Get-Variable -Name SQLServer), (Get-Variable -Name SQLInstanceName)

    Invoke-LabCommand -ComputerName $SQLServer -ActivityName "Setup AlwaysOn Availability Group Endpoint on $SQLServer" -ScriptBlock {
        if ([string]::IsNullOrEmpty($SQLInstanceName)) {
            $SQLInstance = $SQLServer
        } else {
            $SQLInstance = [string]::Concat($SQLServer, '\', $SQLInstanceName)
        }

        $Splat = @{
            SqlInstance = $SQLInstance
            Name        = 'hadr_endpoint'
            Port        = $AGPort
        }
        New-DbaEndpoint @Splat | Start-DbaEndpoint | Format-Table
        New-DbaLogin -SqlInstance $SQLInstance -Login $SQLEngineAccountName | Format-Table
        Invoke-DbaQuery -SqlInstance $SQLInstance -Query "GRANT CONNECT ON ENDPOINT::hadr_endpoint TO [$SQLEngineAccountName]"
    } -PassThru -Variable (Get-Variable -Name SQLServer), (Get-Variable -Name AGPort), (Get-Variable -Name SQLEngineAccountName), (Get-Variable -Name SQLInstanceName)
}

if ($null -eq $AGNodeNamesWithInstanceName) {
    $splat = @{
        ComputerName = $ComputerName
        AGName       = $AGName
        AGDatabase   = $AGDatabase
        Primary      = $AGNodeNames[0]
        Secondary    = $AGNodeNames[1]
        AGIPAddress  = $AGIPAddress
    }
    New-LabAvailabilityGroup @splat
} else {
    $splat = @{
        ComputerName = $ComputerName
        AGName       = $AGName
        AGDatabase   = $AGDatabase
        Primary      = $AGNodeNamesWithInstanceName[0]
        Secondary    = $AGNodeNamesWithInstanceName[1]
        AGIPAddress  = $AGIPAddress
    }
    New-LabAvailabilityGroup @splat
}
