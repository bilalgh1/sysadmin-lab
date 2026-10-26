# 05 — Domain join refused

**Type**: real · **Machine**: PC-USER1

## Symptom

`Add-Computer -DomainName company.local ...` → "Access denied". A first attempt seemed stuck: the credential prompt was hidden behind the PowerShell window.

## Diagnosis

Prerequisites checked, all valid:

| Check | Result |
|---|---|
| `nslookup company.local` | 10.10.20.20 ✅ |
| `nslookup -type=SRV _ldap._tcp.dc._msdcs.company.local` | Points to the DC ✅ |
| `Test-NetConnection` 88 / 389 / 445 / 135 | `True` ✅ |
| `(Get-ADDomain).NetBIOSName` (DC) | `COMPANY` ✅ |

The join log gave the answer:

```powershell
Get-Content C:\Windows\debug\NetSetup.LOG -Tail 30
```

```
SKU: Windows 11 Home
```

Confirmed with `Get-ComputerInfo | Select-Object WindowsProductName, WindowsEditionId` → `Core`. (The "Windows 10" name shown is a registry quirk; rely on the EditionId and the build number.)

## Root cause

**Windows Home cannot join an Active Directory domain.** The log contained no trace of the attempts: the edition refuses before any exchange with the DC.

## Fix

New workstation running **Windows 11 Enterprise (evaluation)**, with a single network adapter on the LAN (the old one was also connected to the IT network, which bypassed segmentation).

Second anomaly: `Add-Computer` still failed, with no trace in `NetSetup.LOG`. The join succeeded through the GUI (`sysdm.cpl`, account `Administrator@company.local`), then the workstation was renamed with `Rename-Computer -DomainCredential`. Root cause of the `Add-Computer` failure not determined.

## Verification

```powershell
Get-ADComputer PC-user1 | Select-Object Name, DistinguishedName   # OU=Postes (thanks to redircmp)
```

`alice.martin` logon: `LOGONSERVER = \\WIN-A5T5IRJE99D`, Kerberos tickets present.

## Lessons learned

- Check the Windows **edition** among domain join prerequisites.
- `NetSetup.LOG` is the first log to read when a domain join fails.
- When a tool fails without explanation and another path works: document the anomaly and move on.
