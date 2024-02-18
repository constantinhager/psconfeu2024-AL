param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $StorageAccountName,

    [Parameter(Mandatory)]
    [string]
    $AccessKey
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Configure Cloud Witness Cluster Quorum' -ScriptBlock {
    Set-ClusterQuorum -CloudWitness -AccountName $StorageAccountName -AccessKey $AccessKey
} -PassThru -Variable (Get-Variable -Name StorageAccountName), (Get-Variable -Name AccessKey)
