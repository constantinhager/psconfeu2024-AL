@{
    AllNodes = @(
        @{
            NodeName                    = '*'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
            Sources                     = 'C:\ClusterStorage\SQLSources\Shares\Sources'
            SOFSName                    = 'LAB2SQLSOF'
            SQLInstanceName             = 'MSSQLSERVER'
            SQLCollation                = 'SQL_Latin1_General_CP1_CI_AS'
            SQLSysAdminAccounts         = 'contoso.com\Administrator'
        },

        @{
            NodeName = 'LAB2SQL1'
            Role     = 'FirstNode'
            Data1    = 'C:\ClusterStorage\SQLData\Shares\Data_LAB2SQL1'
            Log1     = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB2SQL1'
            Backup1  = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB2SQL1'
        },

        @{
            NodeName = 'LAB2SQL2'
            Role     = 'SecondNode'
            Data2    = 'C:\ClusterStorage\SQLData\Shares\Data_LAB2SQL2'
            Log2     = 'C:\ClusterStorage\SQLLog\Shares\Log_LAB2SQL2'
            Backup2  = 'C:\ClusterStorage\SQLBackup\Shares\Backup_LAB2SQL2'
        }
    )
}
