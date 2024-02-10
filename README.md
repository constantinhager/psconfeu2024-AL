# Install Azure VM

# Install Automated Lab
See [script](/Install/InstallAutomatedLab.ps1)

# Add Needed ISOS
The following ISOs are required to deploy the Lab

- Windows Server 2022 Standard or Enterprise Edition (Eval or MSDN or some other source)
- SQL Server 2022 Enterprise Edition (Eval or MSDN or some other source)

Copy them Inside of `$labsources\ISOs`

Endresult:
![ISO Folder](/Assets/ISOFolder.png)

## Misc
to change a lab after it has been created, you can use the following command:
```powershell
Import-LabDefinition -Name LAB1

$netAdapter = New-LabNetworkAdapterDefinition -VirtualSwitch 'NATSwitch' -UseDhcp
Add-LabMachineDefinition -Name LAB1SQL2 -Processors 2 -NetworkAdapter $netAdapter

Install-Lab
```
