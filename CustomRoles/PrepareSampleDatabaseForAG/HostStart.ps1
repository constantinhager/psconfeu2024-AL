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
$SQLInstanceName = $SQLServerVM.Roles.Properties.InstanceName

$SecondSQLServer = Get-LabVM | Where-Object { $_.Roles.Name -like 'SQL*' -and $_.Name -ne "$ComputerName" } | Select-Object -ExpandProperty Name

if ([string]::IsNullOrEmpty($SecondSQLServer)) {
    Write-ScreenInfo -Message 'No second SQL Server found'
    return
}

if ([string]::IsNullOrEmpty($SQLInstance)) {
    $SQLInstance = $ComputerName
    $SecondSQLInstance = $SecondSQLServer
} else {
    $SQLInstance = [string]::Concat($ComputerName, '\', $SQLInstanceName)
    $SecondSQLInstance = [string]::Concat($SecondSQLServer, '\', $SQLInstanceName)
}

foreach ($vm in $SecondSQLServer) {
    Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Backup $DatabaseName on $ComputerName and restore it to $vm" -ScriptBlock {
        $splat = @{
            SqlInstance = $SQLInstance
            Database    = $DatabaseName
            Path        = $BackupPath
            Type        = 'Database'
        }
        Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $SecondSQLInstance -NoRecovery

        $splat = @{
            SqlInstance = $ComputerName
            Database    = $DatabaseName
            Path        = $BackupPath
            Type        = 'Log'
        }
        Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $SecondSQLInstance -Continue -NoRecovery
    } -PassThru -Variable (Get-Variable -Name ComputerName), (Get-Variable -Name BackupPath), (Get-Variable -Name vm), (Get-Variable -Name DatabaseName) , (Get-Variable -Name SQLInstance), (Get-Variable -Name SecondSQLInstance)
}
