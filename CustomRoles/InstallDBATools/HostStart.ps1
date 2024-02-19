param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLVMs = (Get-LabVM -Role SQLServer).Name

# Install dbatools module
foreach ($SQLVM in $SQLVMs) {
    Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Install dbatools' -ScriptBlock {
        if (-not (Get-Module -Name '*PSResourceGet' -ListAvailable)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201
            Install-Module -Name dbatools -Force -Scope AllUsers -SkipPublisherCheck
        } else {
            Install-PSResource -Name dbatools -TrustRepository -Scope AllUsers
        }
    } -PassThru
}
