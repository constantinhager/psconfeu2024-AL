param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

Write-ScreenInfo -Message 'Installing Nuget package provider and PSResourceGet module'
Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Install Nuget and PSResourceGet' -ScriptBlock {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
} -PassThru
