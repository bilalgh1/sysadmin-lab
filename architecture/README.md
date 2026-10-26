# Architecture

## Networks

The network comes from the previous project: an OPNsense firewall routes and filters traffic between three segments.

| Network | Range | Gateway | Content |
|---|---|---|---|
| LAN / Users | 10.10.10.0/24 | 10.10.10.1 | User workstations |
| SERVERS | 10.10.20.0/24 | 10.10.20.1 | DC, Linux server |
| IT / Admin | 10.10.30.0/24 | 10.10.30.1 | Reserved for administration |

User workstations have **a single network adapter**. A machine connected to two segments would act as a bridge and bypass OPNsense filtering.

## Machines

| Machine | OS | Roles | Address | Resources |
|---|---|---|---|---|
| OPNsense | OPNsense | Firewall, routing, DHCP relay to the DC | .1 on each network | 2 GB |
| DC (`WIN-A5T5IRJE99D`) | Windows Server | AD DS (`company.local`), DNS, DHCP, `Partages` share, Windows Server Backup | 10.10.20.20 (static) | 4 GB, 40 GB system disk + 30 GB backup disk |
| SRV-UBUNTU1 | Ubuntu 24.04 LTS | Nginx, SSH | 10.10.20.10 (static) | 2 GB, 10 GB |
| PC-USER1 | Windows 11 Enterprise (evaluation) | Domain member workstation | DHCP | 4 GB, 64 GB, TPM 2.0 + Secure Boot |

## Infrastructure services

### DNS

```
Workstations and servers ──▶ DC (10.10.20.20) ──▶ forwarders 1.1.1.1 / 9.9.9.9
                             authoritative for company.local
```

- Every domain machine queries **the DC**, the only server that knows the `company.local` zone.
- The DC forwards Internet names to two public resolvers.
- The Linux server, not a domain member, has a manually created A record.

### DHCP

- Windows DHCP server on the DC, **authorized in AD**.
- `LAN-Users` scope: 10.10.10.100 to .200, 8-day lease, gateway 10.10.10.1, DNS 10.10.20.20, suffix `company.local`.
- OPNsense **relays** DHCP broadcasts from the LAN to the DC (OPNsense's own DHCP is disabled on that network: one server per network).

### Time

- The DC syncs with `0.fr.pool.ntp.org` and `1.fr.pool.ntp.org` and is the time reference for the domain (Kerberos tolerates 5 minutes of skew).
- DC time zone: Romance Standard Time. Linux server: UTC (logs comparable across servers).

## Required flows between the LAN and the DC

Checked with `Test-NetConnection` before the domain join.

| Port | Protocol | Use |
|---|---|---|
| 53 | DNS | Name resolution, DC location (SRV records) |
| 88 | Kerberos | Authentication |
| 135 + dynamic ports | RPC | Domain join, management |
| 389 | LDAP | Directory queries |
| 445 | SMB | SYSVOL (GPOs), file shares |
| 67/68 | DHCP | Through the OPNsense relay |

## Directory

OU and group names are in French, as in the lab (Utilisateurs = Users, Ordinateurs = Computers, Postes = Workstations, Groupes = Groups, Compta = Accounting, RH = HR).

```
company.local
└── COMPANY
    ├── Utilisateurs
    │   ├── Compta   (alice.martin, bob.durand)
    │   ├── RH       (claire.petit, emma.leroy)
    │   └── IT       (david.moreau)
    ├── Ordinateurs
    │   ├── Postes   (PC-USER1, default destination via redircmp)
    │   └── Serveurs
    ├── Groupes      (GG_Compta, GG_RH, GG_IT, DL_Partage-Compta_RW, DL_Partage-Compta_R, DL_Partage-RH_RW)
    └── Admins
```
