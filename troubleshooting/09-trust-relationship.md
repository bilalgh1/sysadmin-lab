# 09 — Broken trust relationship

**Type**: simulated (tabletop exercise) · **Machine**: PC-USER1

## Symptom

After restoring the workstation from a two-month-old snapshot, no domain account can log on:

> The trust relationship between this workstation and the primary domain failed.

Other workstations work fine.

## Root cause

A member computer has an account in AD, with a password the workstation and the DC change automatically **every 30 days**. The snapshot restored an old password; the DC only accepts the latest one. The **secure channel** between the workstation and the domain can no longer be established.

## Fix

Log on with the **local administrator account** (`.\admin`: `.\` means the local machine), then in an elevated PowerShell:

```powershell
Test-ComputerSecureChannel                                             # False
Test-ComputerSecureChannel -Repair -Credential COMPANY\Administrator
Test-ComputerSecureChannel                                             # True
```

A logoff is then enough. Heavier alternative: remove the workstation from the domain and join it again.

## Lessons learned

- Restoring a snapshot of a domain machine has side effects (same family as the clock of restored VMs, [incident 01](01-dns-ntp.md)).
- **Never restore a DC from a snapshot**: risk of *USN rollback* and replication corruption. Restore a DC from a system state backup.
- The local administrator account is the workstation's fallback access: it must be protected (unique password per machine, LAPS).
