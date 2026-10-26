# 08 — User lost access to the share

**Type**: simulated (tabletop exercise) · **Machines**: DC, PC-USER1

## Symptom

Bob (accounting) no longer has the `S:` drive and sees no folder in `\\win-a5t5irje99d\Partages`. Alice, in the same department, has everything.

## Diagnosis

Method: **compare** what works with what does not. In an AGDLP model, groups grant access.

```powershell
Get-ADUser bob.durand -Properties MemberOf | Select-Object -ExpandProperty MemberOf
#  (empty)
Get-ADUser alice.martin -Properties MemberOf | Select-Object -ExpandProperty MemberOf
#  CN=GG_Compta,OU=Groupes,OU=COMPANY,DC=company,DC=local
```

`MemberOf` does not list the primary group *Domain Users*.

## Root cause

Bob was removed from `GG_Compta`, hence from `DL_Partage-Compta_RW`:
- no `S:` drive: the GPO targeting requires `GG_Compta`;
- no visible folder: ABE hides what he cannot access.

## Fix

```powershell
Add-ADGroupMember -Identity GG_Compta -Members bob.durand
```

Then Bob **logs off and on again**: groups are written into the token and the Kerberos ticket at logon. For a computer group, reboot the machine.

## Investigation

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4729} -MaxEvents 5 | Format-List TimeCreated, Message
```

- **4729**: member removed from a security-enabled global group (who, when, which account).
- **4728**: member added. Monitoring additions to privileged groups is a basic detection rule.

## Lessons learned

- Comparing two similar cases quickly isolates the difference.
- "I added the group but it still doesn't work": the token has not been refreshed.
- Group changes are auditable: the basis of access reviews.
