# 06 — User account locked out

**Type**: real · **Machines**: PC-USER1, DC

## Symptom

At logon: "The referenced account is currently locked out and may not be logged on to" (`COMPANY\alice.martin`).

## Diagnosis

```powershell
Get-ADUser alice.martin -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object Name, LockedOut, BadLogonCount, LastBadPasswordAttempt
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 3 | Format-List TimeCreated, Message
```

Event **4740** (account locked out) shows in *Caller Computer Name* the machine the failures come from: an old password saved somewhere (phone, mapped drive, scheduled task), or a brute-force attack.

## Root cause

The new policy (lockout after 5 failures) did its job after several wrong password entries.

## Fix

```powershell
Unlock-ADAccount alice.martin
# If the password is forgotten:
Set-ADAccountPassword alice.martin -Reset -NewPassword (Read-Host -AsSecureString "New password")
Set-ADUser alice.martin -ChangePasswordAtLogon $true
```

Without intervention, the account unlocks after 15 minutes.

## Lessons learned

- A security control generates support tickets: plan for it when deploying it.
- **Verify the caller's identity** before any password reset: impersonating an employee to the help desk is a very effective social engineering technique.
- An account repeatedly locked out from an unknown machine is a security signal.
