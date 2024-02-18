param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $SOFSName,

    [Parameter(Mandatory)]
    [string]
    $ClusterName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay
$AllFailOverNodes = (Get-LabVM -Role FailoverNode).Name

Invoke-LabCommand -ComputerName $AllFailOverNodes -ActivityName "File Server Role on $($AllFailOverNodes -join ", ")" -ScriptBlock {
    Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
}

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Create Scale-Out File Server $SOFSName inside of Cluster $ClusterName" -ScriptBlock {
    Add-ClusterScaleOutFileServerRole -Name $SOFSName -Cluster $ClusterName
} -PassThru -Variable (Get-Variable -Name SOFSName), (Get-Variable -Name ClusterName)
