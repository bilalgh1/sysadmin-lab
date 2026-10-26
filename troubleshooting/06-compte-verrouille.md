# 06 — Compte utilisateur verrouillé

**Type** : réel · **Machines** : PC-USER1, DC

## Symptôme

À la reconnexion : « Le compte référencé est actuellement verrouillé et il se peut qu'il ne soit pas possible de s'y connecter » (`COMPANY\alice.martin`).

## Diagnostic

```powershell
Get-ADUser alice.martin -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object Name, LockedOut, BadLogonCount, LastBadPasswordAttempt
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 3 | Format-List TimeCreated, Message
```

L'événement **4740** (compte verrouillé) indique dans *Caller Computer Name* la machine d'où viennent les échecs : un ancien mot de passe enregistré quelque part (téléphone, lecteur réseau, tâche planifiée), ou une attaque par force brute.

## Cause racine

La nouvelle politique (verrouillage après 5 échecs) a joué son rôle après plusieurs saisies erronées.

## Correction

```powershell
Unlock-ADAccount alice.martin
# Si le mot de passe est oublié :
Set-ADAccountPassword alice.martin -Reset -NewPassword (Read-Host -AsSecureString "Nouveau mot de passe")
Set-ADUser alice.martin -ChangePasswordAtLogon $true
```

Sans intervention, le compte se déverrouille au bout de 15 minutes.

## Leçons

- Une mesure de sécurité génère du support : à anticiper lors de son déploiement.
- **Vérifier l'identité** de l'appelant avant toute réinitialisation : l'usurpation auprès du support est une technique d'ingénierie sociale très efficace.
- Un compte qui se verrouille en boucle depuis une machine inconnue est un signal de sécurité.
