# 05 — Jonction au domaine refusée

**Type** : réel · **Machine** : PC-USER1

## Symptôme

`Add-Computer -DomainName company.local ...` → « Accès refusé ». Une première tentative semblait bloquée : la fenêtre de saisie du mot de passe était cachée derrière PowerShell.

## Diagnostic

Prérequis vérifiés, tous valides :

| Vérification | Résultat |
|---|---|
| `nslookup company.local` | 10.10.20.20 ✅ |
| `nslookup -type=SRV _ldap._tcp.dc._msdcs.company.local` | Pointe vers le DC ✅ |
| `Test-NetConnection` 88 / 389 / 445 / 135 | `True` ✅ |
| `(Get-ADDomain).NetBIOSName` (DC) | `COMPANY` ✅ |

Le journal de jonction donne la réponse :

```powershell
Get-Content C:\Windows\debug\NetSetup.LOG -Tail 30
```

```
SKU: Windows 11 Home
```

Confirmé par `Get-ComputerInfo | Select-Object WindowsProductName, WindowsEditionId` → `Core`. (Le nom « Windows 10 » affiché est une bizarrerie du registre ; se fier à l'EditionId et au numéro de build.)

## Cause racine

**Windows Home ne peut pas rejoindre un domaine Active Directory.** Le journal ne contenait d'ailleurs aucune trace des tentatives : l'édition refuse avant tout échange avec le DC.

## Correction

Nouveau poste en **Windows 11 Enterprise (évaluation)**, avec une seule carte réseau sur le LAN (l'ancien poste était aussi branché sur le réseau IT, ce qui contournait la segmentation).

Deuxième anomalie : `Add-Computer` a encore échoué, sans aucune trace dans `NetSetup.LOG`. La jonction a réussi par l'interface graphique (`sysdm.cpl`, compte `Administrator@company.local`), puis le poste a été renommé avec `Rename-Computer -DomainCredential`. Cause de l'échec de `Add-Computer` non déterminée.

## Vérification

```powershell
Get-ADComputer PC-user1 | Select-Object Name, DistinguishedName   # OU=Postes (grâce à redircmp)
```

Connexion d'`alice.martin` : `LOGONSERVER = \\WIN-A5T5IRJE99D`, tickets Kerberos présents.

## Leçons

- Vérifier l'**édition** de Windows dans les prérequis d'une jonction.
- `NetSetup.LOG` est le premier journal à lire quand une jonction échoue.
- Quand un outil échoue sans explication et qu'un autre chemin fonctionne : documenter l'anomalie et avancer.
