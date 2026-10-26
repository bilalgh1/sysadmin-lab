# Linux 1 — Comptes, groupes, permissions et sudo

Serveur : SRV-UBUNTU1 (Ubuntu 24.04 LTS).

## Objectif

Deux services (comptabilité et RH) partagent chacun un dossier sur le serveur. Un technicien d'exploitation doit pouvoir redémarrer le serveur web, et rien d'autre.

## Comptes et groupes

| Fichier | Contenu | Lisible par |
|---|---|---|
| `/etc/passwd` | Comptes : nom, UID, groupe principal, home, shell | Tous |
| `/etc/shadow` | Mots de passe hachés (`$6$` = SHA-512), expiration | root et groupe `shadow` |
| `/etc/group` | Groupes et membres secondaires | Tous |

```bash
sudo groupadd compta
sudo groupadd rh
sudo adduser alice      # idem bob, claire, operateur
sudo usermod -aG compta alice
sudo usermod -aG compta bob
sudo usermod -aG rh claire
getent group compta rh
```

> ⚠️ Toujours `usermod -aG`. Sans `-a`, la liste des groupes secondaires est **remplacée** : appliqué à son propre compte, on perd le groupe `sudo`.

Les comptes de service (`sshd`, `www-data`…) ont un UID < 1000 et le shell `/usr/sbin/nologin` : un service tourne sous un compte dédié auquel personne ne peut se connecter.

## Dossiers collaboratifs

Le groupe d'un nouveau fichier vient du **groupe principal** de son créateur. Sans précaution, un fichier créé par alice appartient au groupe `alice`, et bob ne peut pas le modifier.

Le bit **setgid** sur un dossier fait hériter les nouveaux fichiers du groupe du dossier :

```bash
sudo mkdir -p /srv/partages/compta /srv/partages/rh
sudo chown root:compta /srv/partages/compta
sudo chown root:rh /srv/partages/rh
sudo chmod 2770 /srv/partages/compta /srv/partages/rh
sudo ls -ld /srv/partages/*        # drwxrws---
```

- Propriétaire `root` : un dossier de service n'appartient pas à une personne susceptible de partir.
- `770` : tout pour le groupe, rien pour les autres. `2` : setgid (le `s` dans `rws`).
- Le setgid ne s'applique qu'aux **nouveaux** fichiers : les fichiers existants se corrigent avec `chgrp`.

Rappel : sur un dossier, `x` signifie « traverser ». Sans `x` sur un dossier, son contenu est inaccessible, quels que soient les droits des fichiers.

## Délégation sudo au strict nécessaire

```bash
sudo visudo -f /etc/sudoers.d/operateur
```

```
operateur ALL=(root) /usr/bin/systemctl restart nginx
```

- Toujours `visudo` (vérification de syntaxe), un fichier par règle dans `/etc/sudoers.d/`.
- Chemin absolu et arguments exacts : `/usr/bin/systemctl` sans argument permettrait d'arrêter n'importe quel service.
- `systemctl status` n'est **pas** délégué : il fonctionne sans sudo, et son pager (`less`) peut ouvrir un shell root. Même logique pour les éditeurs : on délègue l'édition d'un fichier avec `sudoedit`, jamais `sudo vim`.

## Tests

| Test | Résultat |
|---|---|
| alice crée un fichier dans `compta` | Groupe `compta` ✅ |
| bob modifie le fichier d'alice | Autorisé ✅ |
| claire liste le dossier `compta` | `Permission denied` ✅ |
| `sudo -l` en operateur | Une seule commande : restart nginx ✅ |
| `sudo systemctl stop ssh` en operateur | Refusé ✅ |

## Audit

```bash
grep operateur /var/log/auth.log | tail -5
```

Le journal reconstitue la séquence : `su` vers operateur, sudo autorisé, `command not allowed` pour l'arrêt de SSH, fermeture de session. Le compte d'administration est membre du groupe `adm`, qui donne la lecture des logs sans être root ; operateur ne l'est pas.
