# 08 — Utilisateur privé d'accès au partage

**Type** : simulé (exercice sur table) · **Machines** : DC, PC-USER1

## Symptôme

Bob (Compta) n'a plus le lecteur `S:` et ne voit aucun dossier dans `\\win-a5t5irje99d\Partages`. Alice, du même service, a tout.

## Diagnostic

Méthode : **comparer** ce qui fonctionne avec ce qui ne fonctionne pas. Dans un modèle AGDLP, ce sont les groupes qui donnent l'accès.

```powershell
Get-ADUser bob.durand -Properties MemberOf | Select-Object -ExpandProperty MemberOf
#  (vide)
Get-ADUser alice.martin -Properties MemberOf | Select-Object -ExpandProperty MemberOf
#  CN=GG_Compta,OU=Groupes,OU=COMPANY,DC=company,DC=local
```

`MemberOf` n'affiche pas le groupe principal *Domain Users*.

## Cause racine

Bob a été retiré de `GG_Compta`, donc de `DL_Partage-Compta_RW` :
- pas de lecteur `S:` : le ciblage de la GPO exige `GG_Compta` ;
- aucun dossier visible : l'ABE masque ce à quoi il n'a pas accès.

## Correction

```powershell
Add-ADGroupMember -Identity GG_Compta -Members bob.durand
```

Puis **déconnexion / reconnexion** de Bob : les groupes sont inscrits dans le jeton et le ticket Kerberos à l'ouverture de session. Pour un groupe d'ordinateurs, redémarrage du poste.

## Enquête

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4729} -MaxEvents 5 | Format-List TimeCreated, Message
```

- **4729** : membre retiré d'un groupe global de sécurité (qui, quand, quel compte).
- **4728** : membre ajouté. La surveillance des ajouts aux groupes à privilèges est une règle de détection de base.

## Leçons

- Comparer deux cas similaires isole rapidement la différence.
- « J'ai ajouté le groupe mais ça ne marche pas » : le jeton n'est pas rafraîchi.
- Les modifications de groupes sont auditables : base de la revue des accès.
