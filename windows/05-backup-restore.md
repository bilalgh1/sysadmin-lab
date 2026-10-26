# Windows 5 — Backup and restore

> A backup that has never been restored is only a hypothesis.

## Concepts

- **RPO**: acceptable data loss (time since the last backup).
- **RTO**: maximum time to restore service.
- **3-2-1**: 3 copies, 2 media, 1 offsite, plus an offline or immutable copy against ransomware.

## AD Recycle Bin

```powershell
Enable-ADOptionalFeature "Recycle Bin Feature" -Scope ForestOrConfigurationSet -Target company.local
```

Test: delete then restore a user.

```powershell
Remove-ADUser emma.leroy -Confirm:$false
Get-ADObject -Filter "SamAccountName -eq 'emma.leroy'" -IncludeDeletedObjects | Restore-ADObject
Get-ADUser emma.leroy -Properties MemberOf
```

Result: account enabled, back in its original OU, still a member of `GG_RH`, **same SID**. A recreated account would get a new SID and lose all its access. The Recycle Bin keeps objects for 180 days, but **it is not a backup**: it disappears with the DC.

## Windows Server Backup

Second 30 GB virtual disk on the DC (`E:`).

```powershell
Get-Disk                                          # identify the RAW disk BEFORE acting
Initialize-Disk -Number 1 -PartitionStyle GPT
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter E | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Sauvegarde"

Install-WindowsFeature Windows-Server-Backup
wbadmin start backup -backupTarget:E: -include:C:\Partages -systemState -quiet
wbadmin get versions
```

Restorable: files, volumes, applications, **system state** (AD database, SYSVOL, registry).

Trap: the version identifier is in **UTC** (`10/26/2026-11:02`) while the displayed time is local (12:02).

## Timed restore test

| Time | Action |
|---|---|
| 12:18:57 | alice deletes `S:\test-alice.txt` |
| | Restore **next to** production, content checked |
| | File put back, inherited permissions checked |
| 12:24:01 | alice reads her file again |

```powershell
New-Item -ItemType Directory C:\Restauration     # wbadmin requires an existing folder
wbadmin start recovery -version:10/26/2026-11:02 -itemType:File -items:C:\Partages\Compta\test-alice.txt -recoveryTarget:C:\Restauration -quiet
Copy-Item C:\Restauration\test-alice.txt C:\Partages\Compta\
icacls C:\Partages\Compta\test-alice.txt          # (I) entries inherited from the folder
```

**Measured RTO: about 5 minutes**, including an error (missing target folder) discovered thanks to the test. RPO: no loss here, but not under control without scheduled backups.

## Accepted limitations

| Limitation | In production |
|---|---|
| Backup disk on the same VM and host | Separate backup server, separate credentials |
| No offsite or immutable copy | Offsite and immutable / offline copy |
| Manual backup | Schedule (`wbadmin enable backup`), defined RPO |
| Full AD restore not tested | Regular tests, including DSRM |
| | Never restore a DC from a snapshot (USN rollback) |
