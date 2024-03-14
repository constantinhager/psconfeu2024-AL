Configuration LAB2SQL1_CreateCluster {

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
        $ClusterIPAddress,

        [Parameter(Mandatory)]
        [string]
        $StorageAccountName,

        [Parameter(Mandatory)]
        [string]
        $StorageAccountAccessKey
    )

    Import-DscResource -ModuleName 'FailoverClusterDSC'

    node 'localhost' {

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

        Cluster SQLCluster {
            Name                          = $ClusterName
            DomainAdministratorCredential = $ActiveDirectoryAdministratorCredential
            StaticIPAddress               = $ClusterIPAddress
        }

        ClusterQuorum SQLClusterQuorum {
            IsSingleInstance        = 'Yes'
            Type                    = 'NodeAndCloudMajority'
            Resource                = $StorageAccountName
            StorageAccountAccessKey = $StorageAccountAccessKey
        }
    }
}
