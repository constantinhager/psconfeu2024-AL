# Set Netnat for Virtual Switches
New-NetNat -Name NatIntLab1 -InternalIPInterfaceAddressPrefix 192.168.1.0/24
New-NetNat -Name NatIntLab2 -InternalIPInterfaceAddressPrefix 192.168.2.0/24
New-NetNat -Name NatIntLab3 -InternalIPInterfaceAddressPrefix 192.168.3.0/24
