Configuration LAB2DC
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $SQLSVCCredential
    )

    Import-DscResource -ModuleName 'ActiveDirectoryDSC'
    Import-DscResource -ModuleName 'DnsServerDsc'

    Node 'localhost' {

        ADUser 'sqlsvc' {
            Ensure               = 'Present'
            DomainName           = 'contoso.com'
            UserName             = 'sqlsvc'
            Password             = $SQLSVCCredential
            PasswordNeverExpires = $true
            Path                 = 'CN=Users,DC=contoso,DC=com'
        }

        DnsRecordA 'LAB2SQLCL' {
            Ensure      = 'Present'
            Name        = 'LAB2SQLCL'
            ZoneName    = 'contoso.com'
            IPv4Address = '192.168.2.200'
        }

        DnsRecordA 'LAB2SQLAG' {
            Ensure      = 'Present'
            Name        = 'LAB2SQLAG'
            ZoneName    = 'contoso.com'
            IPv4Address = '192.168.2.201'
        }
    }
}
