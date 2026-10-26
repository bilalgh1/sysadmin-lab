# Linux 3 — Patch management

## Inventaire

```bash
sudo apt update
apt list --upgradable
apt list --upgradable 2>/dev/null | grep -c security
apt list --upgradable 2>/dev/null | grep linux-image
cat /etc/apt/apt.conf.d/20auto-upgrades
```

Constat : **69 mises à jour en attente, dont 56 correctifs de sécurité** (openssh, openssl, sudo, systemd, noyau), alors que les mises à jour automatiques étaient activées.

| Commande | Effet |
|---|---|
| `apt update` | Rafraîchit la liste des paquets, n'installe rien |
| `apt upgrade` | Installe les nouvelles versions sans supprimer de paquet |
| `apt full-upgrade` | Peut ajouter ou supprimer des paquets |

## Pourquoi rien ne s'installait

Enquête complète : [incident 03](../troubleshooting/03-mises-a-jour-bloquees-batterie.md).

Le service `apt-daily-upgrade` porte la condition `ConditionACPower=true`, et unattended-upgrades vérifie lui-même l'alimentation. La VM voyait la batterie du PC portable hôte (`/sys/class/power_supply/AC/online = 0`) et ignorait chaque exécution.

Corrections, sans toucher aux fichiers des paquets :
- [`configs/systemd/apt-daily-upgrade-override.conf`](../configs/systemd/apt-daily-upgrade-override.conf) via `sudo systemctl edit apt-daily-upgrade.service`
- [`configs/apt/51unattended-upgrades-local`](../configs/apt/51unattended-upgrades-local) dans `/etc/apt/apt.conf.d/` (lu après le fichier `50-` d'origine)

Vérification sans rien installer :

```bash
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -iE "battery|will be upgraded"
```

## Fenêtre de maintenance

1. **Retour arrière** : snapshot de la VM (`avant-patch-2026-10-22`).
2. **Application** : `sudo apt update && sudo apt upgrade`, lecture du résumé, conservation des fichiers de configuration modifiés.
3. **Redémarrages** : `needrestart` relance les services concernés ; le nouveau noyau et certains services (dbus, logind) exigent un redémarrage complet (`/var/run/reboot-required.pkgs`).
4. **Vérifications** :

```bash
uname -r                          # 6.8.0-147-generic
systemctl --failed --no-pager     # 0 unité en échec
curl -I http://localhost          # 200 OK
apt list --upgradable             # vide
```

5. **Nettoyage** : suppression du snapshot (un snapshot n'est pas une sauvegarde et ralentit la VM).

Erreurs rencontrées pendant la fenêtre :
- `404 Not Found` : liste de paquets périmée → toujours `apt update` juste avant `apt upgrade`.
- `Release file ... is not valid yet` : horloge de la VM en retard après restauration d'un état enregistré → `sudo systemctl restart systemd-timesyncd`.

## À retenir

- Activer les mises à jour automatiques ne suffit pas : il faut vérifier qu'elles s'appliquent.
- Un correctif noyau n'est actif qu'après redémarrage.
- Une montée de version majeure (24.04 → 26.04) est un projet, pas un patch : non appliquée.
- `xz-utils 5.6.1+really5.4.5` : trace du retour arrière après la porte dérobée xz de 2024 (attaque de la chaîne d'approvisionnement).
