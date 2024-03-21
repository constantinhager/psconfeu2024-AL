@{
    AllNodes = @(
        @{
            NodeName                    = '*'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
        }

        @{
            NodeName  = 'LAB2SQL1'
            Role      = 'FirstNode'
        }

        @{
            NodeName  = 'LAB2SQL2'
            Role      = 'SecondNode'
        }
    )
}
