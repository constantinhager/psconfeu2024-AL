# Create Hyper-V Virtual Switches
New-VMSwitch -Name 'NatSwitchLab1' -SwitchType Internal
New-VMSwitch -Name 'NatSwitchLab2' -SwitchType Internal
New-VMSwitch -Name 'NatSwitchLab3' -SwitchType Internal

# Set Ip Address for Virtual Switches
Get-NetAdapter | Where-Object { $_.Name -eq 'vEthernet (NatSwitchLab1)' } | New-NetIPAddress -IPAddress 192.168.1.1 -PrefixLength 24
Get-NetAdapter | Where-Object { $_.Name -eq 'vEthernet (NatSwitchLab2)' } | New-NetIPAddress -IPAddress 192.168.2.1 -PrefixLength 24
Get-NetAdapter | Where-Object { $_.Name -eq 'vEthernet (NatSwitchLab3)' } | New-NetIPAddress -IPAddress 192.168.3.1 -PrefixLength 24

# Set Netnat for Virtual Switches
New-NetNat -Name NatIntLab1 -InternalIPInterfaceAddressPrefix 192.168.1.0/24
New-NetNat -Name NatIntLab2 -InternalIPInterfaceAddressPrefix 192.168.2.0/24
New-NetNat -Name NatIntLab3 -InternalIPInterfaceAddressPrefix 192.168.3.0/24

# Create DHCP Scopes and Options
Add-DhcpServerv4Scope -Name 192.168.1.0 -Description 'Lab 1 Scope' -SubnetMask 255.255.255.0 -StartRange 192.168.1.10 -EndRange 192.168.1.100
# Use Force because the first dns server is not reachable by the time of creting that scope.
Set-DhcpServerv4OptionValue -ScopeId 192.168.1.0 -DnsServer @('192.168.1.10', '168.63.129.16') -Router 192.168.1.1 -Force

Add-DhcpServerv4Scope -Name 192.168.2.0 -Description 'Lab 2 Scope' -SubnetMask 255.255.255.0 -StartRange 192.168.2.10 -EndRange 192.168.2.100
# Use Force because the first dns server is not reachable by the time of creting that scope.
Set-DhcpServerv4OptionValue -ScopeId 192.168.2.0 -DnsServer @('192.168.2.10', '168.63.129.16') -Router 192.168.2.1 -Force

Add-DhcpServerv4Scope -Name 192.168.3.0 -Description 'Lab 3 Scope' -SubnetMask 255.255.255.0 -StartRange 192.168.3.10 -EndRange 192.168.3.100
# Use Force because the first dns server is not reachable by the time of creting that scope.
Set-DhcpServerv4OptionValue -ScopeId 192.168.3.0 -DnsServer @('192.168.3.10', '168.63.129.16') -Router 192.168.3.1 -Force

# Add Reservations for Scope 192.168.1.0
Add-DhcpServerv4Reservation -ScopeId 192.168.1.0 -IPAddress 192.168.1.10 -ClientId '00-17-fb-00-00-03'
Add-DhcpServerv4Reservation -ScopeId 192.168.1.0 -IPAddress 192.168.1.11 -ClientId '00-17-fb-00-00-0a'
Add-DhcpServerv4Reservation -ScopeId 192.168.1.0 -IPAddress 192.168.1.12 -ClientId '00-17-fb-00-00-09'

# Add Reservations for Scope 192.168.2.0
Add-DhcpServerv4Reservation -ScopeId 192.168.2.0 -IPAddress 192.168.2.10 -ClientId '00-17-fb-00-00-04'
Add-DhcpServerv4Reservation -ScopeId 192.168.2.0 -IPAddress 192.168.2.11 -ClientId '00-17-fb-00-00-0b'
Add-DhcpServerv4Reservation -ScopeId 192.168.2.0 -IPAddress 192.168.2.12 -ClientId '00-17-fb-00-00-0c'

# Add Reservations for Scope 192.168.3.0
Add-DhcpServerv4Reservation -ScopeId 192.168.3.0 -IPAddress 192.168.3.10 -ClientId '00-17-fb-00-00-05'
Add-DhcpServerv4Reservation -ScopeId 192.168.3.0 -IPAddress 192.168.3.11 -ClientId '00-17-fb-00-00-0d'
Add-DhcpServerv4Reservation -ScopeId 192.168.3.0 -IPAddress 192.168.3.12 -ClientId '00-17-fb-00-00-0e'
