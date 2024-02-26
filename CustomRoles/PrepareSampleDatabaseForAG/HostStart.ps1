param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $BackupPath,

    [Parameter()]
    [string]
    $DatabaseName = 'AdventureWorksLT2022'
)

Import-Lab -Name $data.Name -NoValidation -NoDisplay

$SQLServerVM = Get-LabVM -ComputerName $ComputerName
$LABSQLInstanceName = $SQLServerVM.Roles.Properties.InstanceName

$SecondSQLServer = (Get-LabVM -Role SQLServer | Where-Object { $_.Name -ne "$ComputerName" }).Name

if ([string]::IsNullOrEmpty($SecondSQLServer)) {
    Write-ScreenInfo -Message 'No second SQL Server found'
    return
}

if ([string]::IsNullOrEmpty($LABSQLInstanceName)) {
    $SQLInstanceName = $ComputerName
    $SecondSQLInstanceName = $SecondSQLServer
} else {
    $SQLInstanceName = [string]::Concat($ComputerName, '\', $LABSQLInstanceName)
    $SecondSQLInstanceName = [string]::Concat($SecondSQLServer, '\', $LABSQLInstanceName)
}

foreach ($vm in $SecondSQLServer) {
    Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Backup $DatabaseName on $ComputerName and restore it to $vm" -ScriptBlock {
        $splat = @{
            SqlInstance = $SQLInstanceName
            Database    = $DatabaseName
            Path        = $BackupPath
            Type        = 'Database'
        }
        Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $SecondSQLInstanceName -NoRecovery

        $splat = @{
            SqlInstance = $SQLInstanceName
            Database    = $DatabaseName
            Path        = $BackupPath
            Type        = 'Log'
        }
        Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $SecondSQLInstanceName -Continue -NoRecovery
    } -PassThru -Variable (Get-Variable -Name DatabaseName), (Get-Variable -Name SQLInstanceName), (Get-Variable -Name SecondSQLInstanceName)
}
