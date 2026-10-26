# Windows 4 — Partages et permissions NTFS

> Contrainte de lab : le partage est hébergé sur le DC. En production, à proscrire : un DC doit exposer le moins de services possible, et un partage plein remplirait son disque système. On utilise un serveur de fichiers membre, avec quotas.

## Principes

| | Permissions de partage | Permissions NTFS |
|---|---|---|
| S'appliquent | Accès réseau uniquement | Toujours |
| Finesse | Lecture / Modifier / Contrôle total | Fine, par dossier |

- **La plus restrictive des deux l'emporte.**
- Pratique retenue : partage large, toute la finesse dans NTFS, sur les groupes `DL_`.
- Les utilisateurs reçoivent **Modifier**, jamais **Contrôle total** (qui permet de changer les permissions).
- Piège : un dossier créé dans `C:\` hérite de la lecture pour `BUILTIN\Users`, c'est-à-dire tous les utilisateurs du domaine. **On coupe l'héritage.**

## Structure

```
C:\Partages            partage « Partages », ABE activé
├── Compta             DL_Partage-Compta_RW : Modifier | DL_Partage-Compta_R : Lecture
└── RH                 DL_Partage-RH_RW : Modifier
```

## Mise en œuvre

```powershell
New-Item -ItemType Directory C:\Partages
icacls C:\Partages /inheritance:r /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Authenticated Users:(RX)"

New-Item -ItemType Directory C:\Partages\Compta, C:\Partages\RH
icacls C:\Partages\Compta /grant "COMPANY\DL_Partage-Compta_RW:(OI)(CI)M" "COMPANY\DL_Partage-Compta_R:(OI)(CI)RX"
icacls C:\Partages\RH /grant "COMPANY\DL_Partage-RH_RW:(OI)(CI)M"

New-SmbShare -Name "Partages" -Path "C:\Partages" -FullAccess "COMPANY\Domain Admins" -ChangeAccess "Authenticated Users" -FolderEnumerationMode AccessBased
```

- `(OI)(CI)` : la permission se transmet aux fichiers et sous-dossiers.
- `Authenticated Users:(RX)` **sans** `(OI)(CI)` sur la racine : traversée possible, droit non transmis aux sous-dossiers.
- Sous-dossiers créés **après** le réglage de la racine : ils n'héritent que de SYSTEM et Administrators.
- **ABE** (énumération basée sur l'accès) : chacun ne voit que les dossiers auxquels il a accès. L'ABE masque ; ce sont les permissions NTFS qui protègent.

## Résultat

```
C:\Partages\Compta COMPANY\DL_Partage-Compta_R:(OI)(CI)(RX)
                   COMPANY\DL_Partage-Compta_RW:(OI)(CI)(M)
                   NT AUTHORITY\SYSTEM:(I)(OI)(CI)(F)
                   BUILTIN\Administrators:(I)(OI)(CI)(F)
```

Aucune entrée `Users` ni `Authenticated Users` dans les sous-dossiers.

## Tests (alice.martin, Compta)

| Test | Résultat |
|---|---|
| Lister `\\DC\Partages` | Seul `Compta` visible ✅ |
| Écrire dans `S:\` | Autorisé ✅ |
| Accéder à `\\DC\Partages\RH` | « n'existe pas » ✅ (aucun droit, même pas la lecture des attributs : pas de confirmation que le dossier existe) |
