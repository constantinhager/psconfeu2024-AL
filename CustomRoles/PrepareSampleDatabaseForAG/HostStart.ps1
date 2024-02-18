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

$SecondSQLServer = Get-LabVM | Where-Object { $_.Roles.Name -like 'SQL*' -and $_.Name -ne "$ComputerName" } | Select-Object -ExpandProperty Name

Invoke-LabCommand -ComputerName $ComputerName -ActivityName "Backup $DatabaseName on $ComputerName and restore it to $SecondSQLServer" -ScriptBlock {
    $splat = @{
        SqlInstance = $ComputerName
        Database    = $DatabaseName
        Path        = $BackupPath
        Type        = 'Database'
    }
    Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $SecondSQLServer -NoRecovery

    $splat = @{
        SqlInstance = $ComputerName
        Database    = $DatabaseName
        Path        = $BackupPath
        Type        = 'Log'
    }
    Backup-DbaDatabase @splat | Restore-DbaDatabase -SqlInstance $SecondSQLServer -Continue -NoRecovery
} -PassThru -Variable (Get-Variable -Name ComputerName), (Get-Variable -Name BackupPath), (Get-Variable -Name SecondSQLServer), (Get-Variable -Name DatabaseName)
