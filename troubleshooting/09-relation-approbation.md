# 09 — Relation d'approbation rompue

**Type** : simulé (exercice sur table) · **Machine** : PC-USER1

## Symptôme

Après restauration du poste depuis un snapshot vieux de deux mois, aucun compte du domaine ne peut se connecter :

> La relation d'approbation entre cette station de travail et le domaine principal a échoué.

Les autres postes fonctionnent.

## Cause racine

Un ordinateur membre a un compte dans l'AD, avec un mot de passe que le poste et le DC changent automatiquement **tous les 30 jours**. Le snapshot a restauré un ancien mot de passe ; le DC n'accepte que le plus récent. Le **canal sécurisé** entre le poste et le domaine ne s'établit plus.

## Correction

Connexion avec le **compte administrateur local** (`.\admin` : le `.\` désigne la machine locale), puis dans PowerShell en administrateur :

```powershell
Test-ComputerSecureChannel                                             # False
Test-ComputerSecureChannel -Repair -Credential COMPANY\Administrator
Test-ComputerSecureChannel                                             # True
```

Une déconnexion suffit ensuite. Alternative plus lourde : retirer le poste du domaine puis le joindre à nouveau.

## Leçons

- Restaurer un snapshot d'une machine du domaine a des effets de bord (même famille que l'horloge des VM restaurées, [incident 01](01-dns-ntp.md)).
- **Ne jamais restaurer un DC depuis un snapshot** : risque de *USN rollback* et de corruption de la réplication. On restaure un DC à partir d'une sauvegarde de l'état du système.
- Le compte administrateur local est l'accès de secours du poste : il doit être protégé (mot de passe unique par poste, LAPS).
