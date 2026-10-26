# Windows 2 — DHCP, relay and domain join

## DHCP on the DC

DHCP relies on broadcasts, which do not cross a router. The workstation (LAN) and the DC (SERVERS) are on two networks, so OPNsense acts as a **relay agent**: it forwards the request to the DC with the receiving interface address (*giaddr* field = 10.10.10.1), which lets the DC pick the right scope.

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
netsh dhcp add securitygroups
Restart-Service dhcpserver
Add-DhcpServerInDC -DnsName "win-a5t5irje99d.company.local" -IPAddress 10.10.20.20

Add-DhcpServerv4Scope -Name "LAN-Users" -StartRange 10.10.10.100 -EndRange 10.10.10.200 -SubnetMask 255.255.255.0 -LeaseDuration 8.00:00:00 -State Active
Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -Router 10.10.10.1 -DnsServer 10.10.20.20 -DnsDomain company.local
```

- **Authorization in AD**: an unauthorized Windows DHCP server refuses to hand out addresses.
- **.1 to .99 reserved** for statically addressed devices.
- **DNS = the DC**: required to find the domain.

## OPNsense

Recent version (Dnsmasq / Kea instead of ISC DHCP):
1. LAN DHCP range removed (one DHCP server per network).
2. **Services → DHCRelay**: destination 10.10.20.20, relay enabled on the LAN interface.

Check:

```powershell
# Workstation
ipconfig /release ; ipconfig /renew ; ipconfig /all     # DHCP server and DNS = 10.10.20.20
# DC
Get-DhcpServerv4Lease -ScopeId 10.10.10.0
```

## Domain join

### Prerequisites checked before the operation

```powershell
Get-ComputerInfo | Select-Object WindowsProductName, WindowsEditionId   # not "Core" (Home)
Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, PartOfDomain
nslookup company.local
nslookup -type=SRV _ldap._tcp.dc._msdcs.company.local
Test-NetConnection 10.10.20.20 -Port 88      # Kerberos
Test-NetConnection 10.10.20.20 -Port 389     # LDAP
Test-NetConnection 10.10.20.20 -Port 445     # SMB
Test-NetConnection 10.10.20.20 -Port 135     # RPC
```

### Default location for new computers

```powershell
redircmp "OU=Postes,OU=Ordinateurs,OU=COMPANY,DC=company,DC=local"
```

Computer accounts land directly in an OU where GPOs apply.

### Operation

- First workstation running **Windows 11 Home**: join impossible ([incident 05](../troubleshooting/05-domain-join-windows-home.md)). Replaced with Windows 11 Enterprise (evaluation), with a single network adapter on the LAN.
- `Add-Computer` failed ("Access denied") with no trace in `NetSetup.LOG`; the join succeeded through `sysdm.cpl` with `Administrator@company.local`. Root cause not determined.
- Rename within the domain: `Rename-Computer -NewName PC-user1 -DomainCredential COMPANY\Administrator -Restart`.

## First logon of a domain user

```powershell
whoami                                  # company\alice.martin
whoami /groups | findstr /i "GG_ DL_"   # GG_Compta and DL_Partage-Compta_RW
$env:LOGONSERVER                        # \\WIN-A5T5IRJE99D
klist
```

| Ticket | Purpose |
|---|---|
| `krbtgt/COMPANY.LOCAL` | TGT, obtained at logon |
| `LDAP/win-a5t5irje99d...` | Query the directory (which GPOs apply) |
| `cifs/win-a5t5irje99d...` | Read SYSVOL (GPO content) |

AES-256 encryption, 10-hour lifetime, renewable for 7 days. The password is only used once, to get the TGT.

Compared with the local `admin` account: `LOGONSERVER` = the workstation itself, **no Kerberos ticket**: the DC knows nothing about that account.
