param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Installing Nuget package provider and PSResourceGet module' -ScriptBlock {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
} -PassThru
