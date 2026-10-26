# Windows 1 — Active Directory: OUs, groups, AGDLP

Domain `company.local`, empty at the start (only `Administrator`, `Guest`, `krbtgt` and the `Domain Controllers` OU).

## OU or group?

| | OU | Group |
|---|---|---|
| Used to | Organize, link GPOs, delegate administration | Grant permissions |
| An object can be in | A single OU | Several groups |

The default `Users` and `Computers` containers are not OUs: no GPO can be linked to them.

## OU tree

```powershell
New-ADOrganizationalUnit -Name "COMPANY" -Path "DC=company,DC=local"
$root = "OU=COMPANY,DC=company,DC=local"
"Utilisateurs","Ordinateurs","Groupes","Admins" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path $root }
"Compta","RH","IT" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path "OU=Utilisateurs,$root" }
"Postes","Serveurs" | ForEach-Object { New-ADOrganizationalUnit -Name $_ -Path "OU=Ordinateurs,$root" }
```

OUs created this way are protected from accidental deletion.

## AGDLP

```
Accounts → Global groups → Domain Local groups → Permissions
 alice   →   GG_Compta   → DL_Partage-Compta_RW → Modify on \\DC\Partages\Compta
```

```powershell
"GG_Compta","GG_RH","GG_IT" | ForEach-Object { New-ADGroup -Name $_ -GroupScope Global -GroupCategory Security -Path "OU=Groupes,$root" }
"DL_Partage-Compta_RW","DL_Partage-Compta_R","DL_Partage-RH_RW" | ForEach-Object { New-ADGroup -Name $_ -GroupScope DomainLocal -GroupCategory Security -Path "OU=Groupes,$root" }
Add-ADGroupMember -Identity "DL_Partage-Compta_RW" -Members "GG_Compta"
Add-ADGroupMember -Identity "DL_Partage-RH_RW" -Members "GG_RH"
```

**Why never grant a permission directly to a user?** Every arrival, departure or role change would require editing the permissions of every resource, with a high risk of leftovers (privilege creep), and "who has access to what" would become unreadable. With AGDLP, only group membership changes.

## User creation

Script: [`scripts/powershell/New-Users.ps1`](../scripts/powershell/New-Users.ps1), CSV: [`users.example.csv`](../scripts/powershell/users.example.csv).

| Choice | Reason |
|---|---|
| Password prompted at runtime (`Read-Host -AsSecureString`) | Never written in the script or the CSV |
| `ChangePasswordAtLogon` | The administrator never knows the final password |
| Existence check | Idempotent: can be re-run without duplicates |
| `try/catch` + `-ErrorAction Stop` | "Created" only shown on real success |
| Splatting (`@params`) | Readability |

First version: the script printed "Created" despite `Directory object not found` errors (missing OUs). By default, PowerShell prints non-terminating errors and carries on. A script that reports success without checking it is dangerous.

Checks:

```powershell
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,$root" -Properties Department | Select-Object Name, SamAccountName, Department
Get-ADGroupMember GG_Compta
Get-ADGroupMember DL_Partage-Compta_RW      # contains the GG_Compta group
```

## Improvements (IAM project)

- Random, unique initial password per user.
- Separate admin accounts in the `Admins` OU, LAPS.
