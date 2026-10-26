# Windows 1 — Active Directory : OU, groupes, AGDLP

Domaine `company.local`, vierge au départ (seuls `Administrator`, `Guest`, `krbtgt` et l'OU `Domain Controllers`).

## OU ou groupe ?

| | OU | Groupe |
|---|---|---|
| Sert à | Ranger, lier des GPO, déléguer l'administration | Donner des permissions |
| Un objet peut être dans | Une seule OU | Plusieurs groupes |

Les conteneurs par défaut `Users` et `Computers` ne sont pas des OU : aucune GPO ne peut y être liée.

## Arborescence

```powershell
New-ADOrganizationalUnit -Name "COMPANY" -Path "DC=company,DC=local"
$root = "OU=COMPANY,DC=company,DC=local"
"Utilisateurs","Ordinateurs","Groupes","Admins" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path $root }
"Compta","RH","IT" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path "OU=Utilisateurs,$root" }
"Postes","Serveurs" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path "OU=Ordinateurs,$root" }
```

Les OU créées ainsi sont protégées contre la suppression accidentelle.

## AGDLP

```
Accounts → Global groups → Domain Local groups → Permissions
 alice   →   GG_Compta   → DL_Partage-Compta_RW → Modifier sur \\DC\Partages\Compta
```

```powershell
"GG_Compta","GG_RH","GG_IT" | ForEach-Object { New-ADGroup -Name $_ -GroupScope Global -GroupCategory Security -Path "OU=Groupes,$root" }
"DL_Partage-Compta_RW","DL_Partage-Compta_R","DL_Partage-RH_RW" | ForEach-Object { New-ADGroup -Name $_ -GroupScope DomainLocal -GroupCategory Security -Path "OU=Groupes,$root" }
Add-ADGroupMember -Identity "DL_Partage-Compta_RW" -Members "GG_Compta"
Add-ADGroupMember -Identity "DL_Partage-RH_RW" -Members "GG_RH"
```

**Pourquoi ne jamais donner de permission directement à un utilisateur ?** Chaque arrivée, départ ou changement de poste obligerait à retoucher les permissions de toutes les ressources, avec un risque d'oubli (accumulation de privilèges), et « qui a accès à quoi » deviendrait illisible. Avec AGDLP, seule l'appartenance aux groupes change.

## Création des utilisateurs

Script : [`scripts/powershell/New-Users.ps1`](../scripts/powershell/New-Users.ps1), CSV : [`users.example.csv`](../scripts/powershell/users.example.csv).

| Choix | Raison |
|---|---|
| Mot de passe demandé à l'exécution (`Read-Host -AsSecureString`) | Jamais écrit dans le script ni le CSV |
| `ChangePasswordAtLogon` | L'administrateur ne connaît pas le mot de passe final |
| Vérification d'existence | Idempotent : relançable sans doublon |
| `try/catch` + `-ErrorAction Stop` | « Cree » affiché uniquement en cas de succès réel |
| Splatting (`@params`) | Lisibilité |

Première version : le script affichait « Cree » malgré des erreurs `Directory object not found` (OU absentes). Par défaut, PowerShell affiche les erreurs non bloquantes puis continue. Un script qui annonce un succès sans le vérifier est dangereux.

Vérifications :

```powershell
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,$root" -Properties Department | Select-Object Name, SamAccountName, Department
Get-ADGroupMember GG_Compta
Get-ADGroupMember DL_Partage-Compta_RW      # contient le groupe GG_Compta
```

## Améliorations (projet IAM)

- Mot de passe initial aléatoire et unique par utilisateur.
- Comptes d'administration séparés dans l'OU `Admins`, LAPS.
