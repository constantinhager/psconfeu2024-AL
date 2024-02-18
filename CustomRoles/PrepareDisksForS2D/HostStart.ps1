param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLAndFailoverNodes = (Get-LabVM -Role FailoverNode).Name

foreach ($node in $SQLAndFailoverNodes) {
    Invoke-LabCommand -ComputerName $node -ActivityName "Preparing disks for $node" -ScriptBlock {
        Get-Disk | Where-Object Number -NE $null | Where-Object IsBoot -NE $true | Where-Object IsSystem -NE $true | Where-Object PartitionStyle -NE RAW | ForEach-Object {
            $_ | Set-Disk -IsOffline:$false
            $_ | Set-Disk -IsReadOnly:$false
            $_ | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
            $_ | Set-Disk -IsReadOnly:$true
            $_ | Set-Disk -IsOffline:$true
        }
        Get-Disk | Where-Object Number -NE $Null | Where-Object IsBoot -NE $True | Where-Object IsSystem -NE $True | Where-Object PartitionStyle -EQ RAW | Group-Object -NoElement -Property FriendlyName
    } -PassThru
}
