# Windows 5 — Sauvegarde et restauration

> Une sauvegarde qui n'a jamais été restaurée n'est qu'une hypothèse.

## Notions

- **RPO** : perte de données acceptable (temps depuis la dernière sauvegarde).
- **RTO** : temps maximal de rétablissement.
- **3-2-1** : 3 copies, 2 supports, 1 hors site, plus une copie hors ligne ou immuable contre les rançongiciels.

## Corbeille AD

```powershell
Enable-ADOptionalFeature "Recycle Bin Feature" -Scope ForestOrConfigurationSet -Target company.local
```

Test : suppression puis restauration d'un utilisateur.

```powershell
Remove-ADUser emma.leroy -Confirm:$false
Get-ADObject -Filter "SamAccountName -eq 'emma.leroy'" -IncludeDeletedObjects | Restore-ADObject
Get-ADUser emma.leroy -Properties MemberOf
```

Résultat : compte activé, dans son OU d'origine, toujours membre de `GG_RH`, **même SID**. Un compte recréé aurait un nouveau SID et perdrait tous ses accès. La corbeille garde les objets 180 jours, mais **n'est pas une sauvegarde** : elle disparaît avec le DC.

## Windows Server Backup

Second disque virtuel de 30 Go sur le DC (`E:`).

```powershell
Get-Disk                                          # identifier le disque RAW AVANT d'agir
Initialize-Disk -Number 1 -PartitionStyle GPT
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter E | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Sauvegarde"

Install-WindowsFeature Windows-Server-Backup
wbadmin start backup -backupTarget:E: -include:C:\Partages -systemState -quiet
wbadmin get versions
```

Restauration possible : fichiers, volumes, applications, **état du système** (base AD, SYSVOL, registre).

Piège : l'identificateur de version est en **UTC** (`10/26/2026-11:02`) alors que l'heure affichée est locale (12:02).

## Test de restauration chronométré

| Heure | Action |
|---|---|
| 12:18:57 | alice supprime `S:\test-alice.txt` |
| | Restauration **à côté** de la production, contrôle du contenu |
| | Remise en place, vérification des permissions héritées |
| 12:24:01 | alice relit son fichier |

```powershell
New-Item -ItemType Directory C:\Restauration     # wbadmin exige un dossier existant
wbadmin start recovery -version:10/26/2026-11:02 -itemType:File -items:C:\Partages\Compta\test-alice.txt -recoveryTarget:C:\Restauration -quiet
Copy-Item C:\Restauration\test-alice.txt C:\Partages\Compta\
icacls C:\Partages\Compta\test-alice.txt          # entrées (I) héritées du dossier
```

**RTO mesuré : environ 5 minutes**, y compris une erreur (dossier cible absent) découverte grâce au test. RPO : aucune perte ici, mais non maîtrisé sans sauvegarde planifiée.

## Limites assumées

| Limite | En entreprise |
|---|---|
| Disque de sauvegarde sur la même VM et le même hôte | Serveur de sauvegarde séparé, droits distincts |
| Pas de copie hors site ni immuable | Copie externalisée et immuable / hors ligne |
| Sauvegarde manuelle | Planification (`wbadmin enable backup`), RPO défini |
| Restauration complète de l'AD non testée | Tests réguliers, y compris en mode DSRM |
| | Ne jamais restaurer un DC depuis un snapshot (USN rollback) |
