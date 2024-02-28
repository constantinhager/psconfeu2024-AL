param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$LabVMs = (Get-LabVM | Where-Object { $_.Roles.Name -notlike '*DC*' }).Name

foreach ($LabVM in $LabVMs) {

    Invoke-LabCommand -ComputerName $LabVM -ActivityName 'Wait until PSGallery is registered.' -ScriptBlock {
        while ($null -eq (Get-PSRepository)) {
            Start-Sleep -Seconds 5
        }
    } -PassThru

    Invoke-LabCommand -ComputerName $LabVM -ActivityName 'Installing Nuget package provider and PSResourceGet module' -ScriptBlock {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force -Scope AllUsers
    } -PassThru
}
