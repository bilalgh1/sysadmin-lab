# Windows 2 — DHCP, relais et jonction au domaine

## DHCP sur le DC

Le DHCP fonctionne par diffusion, qui ne traverse pas un routeur. Le poste (LAN) et le DC (SERVERS) étant sur deux réseaux, OPNsense joue le rôle de **relais** : il transmet la demande au DC en indiquant l'interface d'origine (champ *giaddr* = 10.10.10.1), ce qui permet au DC de choisir la bonne étendue.

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
netsh dhcp add securitygroups
Restart-Service dhcpserver
Add-DhcpServerInDC -DnsName "win-a5t5irje99d.company.local" -IPAddress 10.10.20.20

Add-DhcpServerv4Scope -Name "LAN-Users" -StartRange 10.10.10.100 -EndRange 10.10.10.200 -SubnetMask 255.255.255.0 -LeaseDuration 8.00:00:00 -State Active
Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -Router 10.10.10.1 -DnsServer 10.10.20.20 -DnsDomain company.local
```

- **Autorisation dans l'AD** : un serveur DHCP Windows non autorisé refuse de distribuer des adresses.
- **.1 à .99 réservés** aux équipements à adresse fixe.
- **DNS = le DC** : indispensable pour trouver le domaine.

## OPNsense

Version récente (Dnsmasq / Kea à la place d'ISC DHCP) :
1. Suppression de la plage DHCP du LAN (un seul serveur DHCP par réseau).
2. **Services → DHCRelay** : destination 10.10.20.20, relais activé sur l'interface LAN.

Vérification :

```powershell
# Poste
ipconfig /release ; ipconfig /renew ; ipconfig /all     # serveur DHCP et DNS = 10.10.20.20
# DC
Get-DhcpServerv4Lease -ScopeId 10.10.10.0
```

## Jonction au domaine

### Prérequis vérifiés avant l'opération

```powershell
Get-ComputerInfo | Select-Object WindowsProductName, WindowsEditionId   # pas « Core » (Home)
Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, PartOfDomain
nslookup company.local
nslookup -type=SRV _ldap._tcp.dc._msdcs.company.local
Test-NetConnection 10.10.20.20 -Port 88      # Kerberos
Test-NetConnection 10.10.20.20 -Port 389     # LDAP
Test-NetConnection 10.10.20.20 -Port 445     # SMB
Test-NetConnection 10.10.20.20 -Port 135     # RPC
```

### Destination des nouveaux ordinateurs

```powershell
redircmp "OU=Postes,OU=Ordinateurs,OU=COMPANY,DC=company,DC=local"
```

Les comptes ordinateurs arrivent directement dans une OU où les GPO s'appliquent.

### Opération

- Premier poste en **Windows 11 Home** : jonction impossible ([incident 05](../troubleshooting/05-jonction-windows-home.md)). Remplacé par Windows 11 Enterprise (évaluation), une seule carte réseau sur le LAN.
- `Add-Computer` a échoué (« Accès refusé ») sans trace dans `NetSetup.LOG` ; la jonction a réussi par `sysdm.cpl` avec `Administrator@company.local`. Cause non déterminée.
- Renommage dans le domaine : `Rename-Computer -NewName PC-user1 -DomainCredential COMPANY\Administrator -Restart`.

## Première connexion d'un utilisateur du domaine

```powershell
whoami                                  # company\alice.martin
whoami /groups | findstr /i "GG_ DL_"   # GG_Compta et DL_Partage-Compta_RW
$env:LOGONSERVER                        # \\WIN-A5T5IRJE99D
klist
```

| Ticket | Rôle |
|---|---|
| `krbtgt/COMPANY.LOCAL` | TGT, obtenu à l'ouverture de session |
| `LDAP/win-a5t5irje99d...` | Interroger l'annuaire (quelles GPO s'appliquent) |
| `cifs/win-a5t5irje99d...` | Lire SYSVOL (contenu des GPO) |

Chiffrement AES-256, validité 10 h, renouvelable 7 jours. Le mot de passe n'est utilisé qu'une fois, pour obtenir le TGT.

Comparaison avec le compte local `admin` : `LOGONSERVER` = le poste lui-même, **aucun ticket Kerberos** : le DC ignore tout de ce compte.
