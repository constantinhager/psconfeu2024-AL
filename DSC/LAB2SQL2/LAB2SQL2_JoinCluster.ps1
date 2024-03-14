Configuration LAB2SQL2_JoinCluster {
    param
    (
        [Parameter(Mandatory)]
        [pscredential]
        $ActiveDirectoryAdministratorCredential,

        [Parameter(Mandatory)]
        [string]
        $ClusterName,

        [Parameter(Mandatory)]
        [string]
        $ClusterIPAddress
    )

    Import-DscResource -ModuleName 'FailoverClusterDSC'

    Node 'localhost' {
        WindowsFeature AddFailoverFeature {
            Ensure = 'Present'
            Name   = 'Failover-Clustering'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringPowerShellFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]AddFailoverFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-CmdInterface'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusterManagementTool {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-Mgmt'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        WaitForCluster WaitForCluster {
            Name             = $ClusterName
            RetryIntervalSec = 10
            RetryCount       = 60
            DependsOn        = '[WindowsFeature]AddRemoteServerAdministrationToolsClusterManagementTool'
        }

        Cluster SQLCluster {
            Name                          = $ClusterName
            DomainAdministratorCredential = $ActiveDirectoryAdministratorCredential
            StaticIPAddress               = $ClusterIPAddress
            DependsOn                     = '[WaitForCluster]WaitForCluster'
        }
    }
}
