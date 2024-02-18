param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Enable Storage Spaces Direct' -ScriptBlock {
    Enable-ClusterStorageSpacesDirect -Confirm:$false
} -PassThru
