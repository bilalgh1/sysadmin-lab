# Windows 3 — Group Policy (GPO)

## Principles

- A GPO is **linked to an OU** and applies to the objects it contains.
- **Computer configuration**: at startup. **User configuration**: at logon.
- **LSDOU** order (Local, Site, Domain, OU): the last one applied wins.
- Automatic refresh every ~90 minutes.
- Naming convention: `U_` (user), `C_` (computer).

## Password and lockout policy

It **only works at domain level** (Default Domain Policy); linked to an OU, it would have no effect on domain accounts.

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity company.local -MinPasswordLength 12 -LockoutThreshold 5 -LockoutDuration 00:15:00 -LockoutObservationWindow 00:15:00
Get-ADDefaultDomainPasswordPolicy
```

| Setting | Value |
|---|---|
| Minimum length | 12 (instead of 7) |
| Lockout | After 5 failures, 15 min (default: **0 = never**) |
| Complexity | Enabled |
| History | 24 |
| Reversible encryption | Disabled |

Up for discussion: forced expiry every 42 days is now discouraged (NIST, ANSSI) because it leads to predictable passwords. Current guidance: long passwords, changed on suspected compromise, plus MFA.

## U_Restrictions_Utilisateurs (Users OU)

```powershell
$root = "OU=COMPANY,DC=company,DC=local"
New-GPO -Name "U_Restrictions_Utilisateurs" | New-GPLink -Target "OU=Utilisateurs,$root"
Set-GPRegistryValue -Name "U_Restrictions_Utilisateurs" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoControlPanel" -Type DWord -Value 1
```

- Control Panel and Settings blocked.
- **Preference**: `S:` drive mapped to `\\win-a5t5irje99d.company.local\Partages\Compta`, with **item-level targeting** on `GG_Compta` (User Configuration → Preferences → Windows Settings → Drive Maps).

## C_Securite_Postes (Workstations OU)

```powershell
New-GPO -Name "C_Securite_Postes" | New-GPLink -Target "OU=Postes,OU=Ordinateurs,$root"
$k = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"
Set-GPRegistryValue -Name "C_Securite_Postes" -Key $k -ValueName "InactivityTimeoutSecs" -Type DWord -Value 600
Set-GPRegistryValue -Name "C_Securite_Postes" -Key $k -ValueName "LegalNoticeCaption" -Type String -Value "Avertissement"
Set-GPRegistryValue -Name "C_Securite_Postes" -Key $k -ValueName "LegalNoticeText" -Type String -Value "Acces reserve aux personnes autorisees. Toute connexion est journalisee."
```

- Session locked after 10 minutes of inactivity.
- Legal notice before logon ("Access restricted to authorized persons. All connections are logged."), which informs users that access is monitored.

## Verification

```powershell
gpupdate /force
gpresult /r       # the computer section only shows with admin rights
```

| Test | Result |
|---|---|
| alice opens the Control Panel | "This operation has been cancelled due to restrictions" ✅ |
| Workstation reboot | Legal notice shown before logon ✅ |
| alice logs on again | `Compta (S:)` drive present ✅ |
| Local `admin` account | Not affected (outside the targeted OU) ✅ |
