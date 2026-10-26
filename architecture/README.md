# Architecture

## Réseaux

Le réseau est hérité du projet précédent : un pare-feu OPNsense route et filtre le trafic entre trois segments.

| Réseau | Plage | Passerelle | Contenu |
|---|---|---|---|
| LAN / Utilisateurs | 10.10.10.0/24 | 10.10.10.1 | Postes utilisateurs |
| SERVERS | 10.10.20.0/24 | 10.10.20.1 | DC, serveur Linux |
| IT / Admin | 10.10.30.0/24 | 10.10.30.1 | Réservé à l'administration |

Les postes utilisateurs n'ont **qu'une seule carte réseau**. Une machine branchée sur deux segments servirait de pont et contournerait le filtrage d'OPNsense.

## Machines

| Machine | Système | Rôles | Adresse | Ressources |
|---|---|---|---|---|
| OPNsense | OPNsense | Pare-feu, routage, relais DHCP vers le DC | .1 sur chaque réseau | 2 Go |
| DC (`WIN-A5T5IRJE99D`) | Windows Server | AD DS (`company.local`), DNS, DHCP, partage `Partages`, Windows Server Backup | 10.10.20.20 (fixe) | 4 Go, disque système 40 Go + disque de sauvegarde 30 Go |
| SRV-UBUNTU1 | Ubuntu 24.04 LTS | Nginx, SSH | 10.10.20.10 (fixe) | 2 Go, 10 Go |
| PC-USER1 | Windows 11 Enterprise (évaluation) | Poste membre du domaine | DHCP | 4 Go, 64 Go, TPM 2.0 + Secure Boot |

## Services d'infrastructure

### DNS

```
Postes et serveurs ──▶ DC (10.10.20.20) ──▶ redirecteurs 1.1.1.1 / 9.9.9.9
                       autorité sur company.local
```

- Toutes les machines du domaine interrogent **le DC**, qui seul connaît la zone `company.local`.
- Le DC transmet les noms Internet à deux redirecteurs publics.
- Le serveur Linux, non membre du domaine, a un enregistrement A créé manuellement.

### DHCP

- Serveur DHCP Windows sur le DC, **autorisé dans l'AD**.
- Étendue `LAN-Users` : 10.10.10.100 à .200, bail 8 jours, passerelle 10.10.10.1, DNS 10.10.20.20, suffixe `company.local`.
- OPNsense **relaie** les diffusions DHCP du LAN vers le DC (le DHCP d'OPNsense est désactivé sur ce réseau : un seul serveur par réseau).

### Temps

- Le DC se synchronise sur `0.fr.pool.ntp.org` et `1.fr.pool.ntp.org` et sert de référence au domaine (Kerberos tolère 5 minutes d'écart).
- Fuseau du DC : Romance Standard Time. Serveur Linux : UTC (logs comparables entre serveurs).

## Flux nécessaires entre le LAN et le DC

Vérifiés avec `Test-NetConnection` avant la jonction au domaine.

| Port | Protocole | Usage |
|---|---|---|
| 53 | DNS | Résolution, localisation du DC (enregistrements SRV) |
| 88 | Kerberos | Authentification |
| 135 + ports dynamiques | RPC | Jonction, gestion |
| 389 | LDAP | Interrogation de l'annuaire |
| 445 | SMB | SYSVOL (GPO), partages de fichiers |
| 67/68 | DHCP | Via le relais OPNsense |

## Annuaire

```
company.local
└── COMPANY
    ├── Utilisateurs
    │   ├── Compta   (alice.martin, bob.durand)
    │   ├── RH       (claire.petit, emma.leroy)
    │   └── IT       (david.moreau)
    ├── Ordinateurs
    │   ├── Postes   (PC-USER1, destination par défaut via redircmp)
    │   └── Serveurs
    ├── Groupes      (GG_Compta, GG_RH, GG_IT, DL_Partage-Compta_RW, DL_Partage-Compta_R, DL_Partage-RH_RW)
    └── Admins
```
