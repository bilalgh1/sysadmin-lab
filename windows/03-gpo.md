# Windows 3 — Stratégies de groupe (GPO)

## Principes

- Une GPO est **liée à une OU** et s'applique aux objets qu'elle contient.
- **Configuration ordinateur** : au démarrage. **Configuration utilisateur** : à l'ouverture de session.
- Ordre **LSDOU** (Local, Site, Domaine, OU) : la dernière appliquée l'emporte.
- Rafraîchissement automatique toutes les ~90 minutes.
- Convention de nommage : `U_` (utilisateur), `C_` (ordinateur).

## Politique de mots de passe et de verrouillage

Elle ne fonctionne **qu'au niveau du domaine** (Default Domain Policy) ; liée à une OU, elle n'aurait aucun effet sur les comptes du domaine.

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity company.local -MinPasswordLength 12 -LockoutThreshold 5 -LockoutDuration 00:15:00 -LockoutObservationWindow 00:15:00
Get-ADDefaultDomainPasswordPolicy
```

| Paramètre | Valeur |
|---|---|
| Longueur minimale | 12 (au lieu de 7) |
| Verrouillage | Après 5 échecs, 15 min (défaut : **0 = jamais**) |
| Complexité | Activée |
| Historique | 24 |
| Chiffrement réversible | Désactivé |

À discuter : l'expiration forcée tous les 42 jours est aujourd'hui déconseillée (NIST, ANSSI) car elle pousse à des mots de passe prévisibles. Recommandation actuelle : mots de passe longs, changement en cas de compromission, MFA.

## U_Restrictions_Utilisateurs (OU Utilisateurs)

```powershell
$root = "OU=COMPANY,DC=company,DC=local"
New-GPO -Name "U_Restrictions_Utilisateurs" | New-GPLink -Target "OU=Utilisateurs,$root"
Set-GPRegistryValue -Name "U_Restrictions_Utilisateurs" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoControlPanel" -Type DWord -Value 1
```

- Interdiction du Panneau de configuration et des Paramètres.
- **Préférence** : lecteur `S:` vers `\\win-a5t5irje99d.company.local\Partages\Compta`, avec **ciblage au niveau de l'élément** sur `GG_Compta` (Configuration utilisateur → Préférences → Paramètres Windows → Mappages de lecteurs).

## C_Securite_Postes (OU Postes)

```powershell
New-GPO -Name "C_Securite_Postes" | New-GPLink -Target "OU=Postes,OU=Ordinateurs,$root"
$k = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"
Set-GPRegistryValue -Name "C_Securite_Postes" -Key $k -ValueName "InactivityTimeoutSecs" -Type DWord -Value 600
Set-GPRegistryValue -Name "C_Securite_Postes" -Key $k -ValueName "LegalNoticeCaption" -Type String -Value "Avertissement"
Set-GPRegistryValue -Name "C_Securite_Postes" -Key $k -ValueName "LegalNoticeText" -Type String -Value "Acces reserve aux personnes autorisees. Toute connexion est journalisee."
```

- Verrouillage de session après 10 minutes d'inactivité.
- Bannière légale avant la connexion (informe que les accès sont contrôlés).

## Vérification

```powershell
gpupdate /force
gpresult /r       # la section ordinateur n'apparaît qu'avec des droits d'administration
```

| Test | Résultat |
|---|---|
| alice ouvre le Panneau de configuration | « Cette opération a été annulée en raison de restrictions » ✅ |
| Redémarrage du poste | Bannière « Avertissement » avant la connexion ✅ |
| Reconnexion d'alice | Lecteur `Compta (S:)` présent ✅ |
| Compte local `admin` | Non concerné (hors de l'OU ciblée) ✅ |
