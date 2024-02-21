param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$LabVM = Get-LabVM -ComputerName $ComputerName

$SVCAccount = ($LabVM.roles | Where-Object { $_.Name -Like 'SQL*' }).Properties.SQLSvcAccount
