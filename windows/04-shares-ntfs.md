# Windows 4 — File shares and NTFS permissions

> Lab constraint: the share is hosted on the DC. In production, avoid it: a DC must expose as few services as possible, and a full share would fill its system disk. Use a dedicated member file server, with quotas.

## Principles

| | Share permissions | NTFS permissions |
|---|---|---|
| Apply to | Network access only | Always |
| Granularity | Read / Change / Full control | Fine-grained, per folder |

- **The most restrictive of the two wins.**
- Practice used: broad share permissions, all granularity in NTFS, on `DL_` groups.
- Users get **Modify**, never **Full control** (which lets them change permissions).
- Trap: a folder created under `C:\` inherits Read for `BUILTIN\Users`, i.e. every domain user. **Break inheritance.**

## Structure

```
C:\Partages            "Partages" share, ABE enabled
├── Compta             DL_Partage-Compta_RW: Modify | DL_Partage-Compta_R: Read
└── RH                 DL_Partage-RH_RW: Modify
```

## Implementation

```powershell
New-Item -ItemType Directory C:\Partages
icacls C:\Partages /inheritance:r /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Authenticated Users:(RX)"

New-Item -ItemType Directory C:\Partages\Compta, C:\Partages\RH
icacls C:\Partages\Compta /grant "COMPANY\DL_Partage-Compta_RW:(OI)(CI)M" "COMPANY\DL_Partage-Compta_R:(OI)(CI)RX"
icacls C:\Partages\RH /grant "COMPANY\DL_Partage-RH_RW:(OI)(CI)M"

New-SmbShare -Name "Partages" -Path "C:\Partages" -FullAccess "COMPANY\Domain Admins" -ChangeAccess "Authenticated Users" -FolderEnumerationMode AccessBased
```

- `(OI)(CI)`: the permission propagates to files and subfolders.
- `Authenticated Users:(RX)` **without** `(OI)(CI)` on the root: users can traverse it, but the right does not propagate to subfolders.
- Subfolders created **after** the root is set: they only inherit SYSTEM and Administrators.
- **ABE** (access-based enumeration): users only see the folders they can access. ABE hides; NTFS permissions protect.

## Result

```
C:\Partages\Compta COMPANY\DL_Partage-Compta_R:(OI)(CI)(RX)
                   COMPANY\DL_Partage-Compta_RW:(OI)(CI)(M)
                   NT AUTHORITY\SYSTEM:(I)(OI)(CI)(F)
                   BUILTIN\Administrators:(I)(OI)(CI)(F)
```

No `Users` or `Authenticated Users` entry on the subfolders.

## Tests (alice.martin, accounting)

| Test | Result |
|---|---|
| List `\\DC\Partages` | Only `Compta` visible ✅ |
| Write to `S:\` | Allowed ✅ |
| Open `\\DC\Partages\RH` | "path does not exist" ✅ (no rights at all, not even reading attributes: no confirmation that the folder exists) |
