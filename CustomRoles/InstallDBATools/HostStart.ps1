param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

# Check if PSResourceGet is installed
Write-ScreenInfo -Message 'Check if PowerShell module PSResourceGet is installed'
$usePSResourceGet = Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Check if PSResourceGet is installed' -ScriptBlock {
    if (-not (Get-Module -Name '*PSResourceGet' -ListAvailable)) {
        return $false
    }
    return $true
} -PassThru

# Install dbatools module
Write-ScreenInfo -Message 'Installing dbatools module'
Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Install dbatools' -ScriptBlock {
    if ($usePSResourceGet) {
        Install-PSResource -Name dbatools -TrustRepository -Scope AllUsers
    } else {
        Install-Module -Name dbatools -Force -Scope AllUsers
    }
} -PassThru -Variable (Get-Variable -Name usePSResourceGet)
