# 03 — 56 correctifs de sécurité jamais installés

**Type** : réel · **Machine** : SRV-UBUNTU1

## Symptôme

`apt list --upgradable` : 69 mises à jour en attente, dont 56 de sécurité, alors que `/etc/apt/apt.conf.d/20auto-upgrades` active les mises à jour automatiques.

## Diagnostic

| Étape | Commande | Constat |
|---|---|---|
| Les timers tournent-ils ? | `systemctl list-timers apt-daily*` | Oui, déclenchés au démarrage |
| Que dit l'outil ? | `tail /var/log/unattended-upgrades/unattended-upgrades.log` | Fichier **vide** |
| Que dit systemd ? | `journalctl -u apt-daily-upgrade.service` | `skipped because of an unmet condition check (ConditionACPower=true)` depuis le 26/09 |
| Que voit la VM ? | `ls /sys/class/power_supply/`, `cat .../online` | `AC` et `BAT0`, secteur à `0` |
| Logs archivés | `sudo zcat .../unattended-upgrades.log.1.gz` | `WARNING System is on battery power, stopping` |

Trois hypothèses avaient été formulées (DNS en panne, VM souvent éteinte, verrou apt). **Aucune n'était la bonne** : seule la vérification dans les journaux a révélé la cause.

Le log « vide » avait été archivé par **logrotate** : quand un log est vide, chercher ses versions `.1`, `.2.gz`.

## Cause racine

VirtualBox transmet à la VM l'état de la batterie du PC portable hôte. Deux contrôles indépendants empêchaient l'installation sur batterie :
1. `ConditionACPower=true` dans `apt-daily-upgrade.service` ;
2. la vérification propre à unattended-upgrades.

## Correction

Les deux niveaux, sans modifier les fichiers des paquets :
- [`configs/systemd/apt-daily-upgrade-override.conf`](../configs/systemd/apt-daily-upgrade-override.conf)
- [`configs/apt/51unattended-upgrades-local`](../configs/apt/51unattended-upgrades-local)

## Vérification

```bash
systemctl cat apt-daily-upgrade.service      # surcharge ConditionACPower= en fin de fichier
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -iE "battery|will be upgraded"
```

Liste des paquets à mettre à jour affichée, aucune mention de la batterie. Correctifs ensuite appliqués lors d'une fenêtre de maintenance ([linux/03](../linux/03-mises-a-jour.md)).

## Leçons

- Activer une automatisation ne suffit pas : il faut vérifier qu'elle produit son effet. À superviser : le nombre de correctifs de sécurité en attente.
- Une même règle peut être appliquée à plusieurs niveaux.
- Ne pas retenir une explication plausible sans l'avoir confirmée.
