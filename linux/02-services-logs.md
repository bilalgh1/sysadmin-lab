# Linux 2 — Nom d'hôte, services systemd et logs

## Renommage du serveur

```bash
sudo hostnamectl set-hostname srv-ubuntu1
sudo nano /etc/hosts          # 127.0.1.1  srv-ubuntu1
sudo reboot                   # vérifier que le nom persiste
```

Sans mise à jour de `/etc/hosts`, `sudo` ne résout plus le nom de sa propre machine.

Le serveur n'étant pas membre du domaine, il ne s'enregistre pas dans le DNS. Piège rencontré : `resolvectl query srv-ubuntu1` répond `127.0.1.1` avec `Data from: synthetic`, une réponse fabriquée localement. Le vrai test interroge le DC :

```bash
dig @10.10.20.20 srv-ubuntu1.company.local      # NXDOMAIN avant création
```

```powershell
# Sur le DC
Add-DnsServerResourceRecordA -ZoneName "company.local" -Name "srv-ubuntu1" -IPv4Address "10.10.20.10"
```

Après création : `NOERROR`, drapeau `aa` (le DC fait autorité sur la zone).

## Processus et séparation des privilèges

```bash
ps -o user,pid,ppid,cmd -C nginx
```

| Processus | Utilisateur | Parent |
|---|---|---|
| master | `root` | PID 1 (systemd) |
| worker | `www-data` | master |

Le master a besoin de root pour ouvrir le port 80 (< 1024). Les workers, qui traitent les requêtes des visiteurs, n'ont aucun privilège : une faille exploitée donne les droits de `www-data`, pas de root.

| Commande | Question |
|---|---|
| `systemctl is-active nginx` | Tourne-t-il maintenant ? |
| `systemctl is-enabled nginx` | Démarrera-t-il au prochain boot ? |
| `systemctl list-units --type=service --state=running` | Que tourne-t-il sur ce serveur ? |

Services inutiles repérés sur un serveur virtuel : ModemManager (désactivé), upower, udisks2, multipathd. SSH n'apparaît pas : depuis Ubuntu 22.10, il est activé **par socket** (`ssh.socket`).

## Signaux et relance automatique

| Signal | Effet |
|---|---|
| `SIGTERM` (15) | Arrêt propre, défaut de `kill` |
| `SIGKILL` (9) | Arrêt immédiat par le noyau |
| `SIGHUP` (1) | Souvent : relire la configuration (`systemctl reload`) |

Expériences :
- Worker tué : le master en relance un immédiatement.
- Master tué avec `kill -9` : systemd nettoie le cgroup, le service passe en `failed` et **n'est pas relancé**. Le site tombe.

Correction par **surcharge** (*drop-in*), sans modifier le fichier fourni par le paquet :

```bash
sudo systemctl edit nginx
```

Contenu : [`configs/systemd/nginx-override.conf`](../configs/systemd/nginx-override.conf). Vérification : `systemctl cat nginx`, puis rejeu de l'incident → `Scheduled restart job, restart counter is at 1`, service rétabli en 5 secondes.

La relance automatique doit être couplée à une supervision qui alerte sur chaque redémarrage, sinon les plantages passent inaperçus. systemd cesse de relancer après 5 échecs en 10 secondes.

## Logs

| Source | Outil |
|---|---|
| Services systemd, noyau | `journalctl` |
| Fichiers texte classiques (`auth.log`, `syslog`) | rsyslog, `/var/log/` |
| Applications | ex. `/var/log/nginx/access.log`, `error.log` |

```bash
journalctl -u nginx --since today
journalctl --list-boots
journalctl -b -p err --no-pager
tail -f /var/log/nginx/access.log
sudo zcat -f /var/log/unattended-upgrades/unattended-upgrades.log* | tail
```

Méthode de tri des erreurs, appliquée aux 12 erreurs du démarrage :

| Message | Verdict |
|---|---|
| `vmwgfx ... unsupported hypervisor` | Bruit : pilote d'affichage sous VirtualBox |
| `pam_lastlog.so` introuvable | Bug connu d'Ubuntu 24.04, sans impact |
| `watchdog: BUG: soft lockup` | La VM n'a pas reçu de CPU pendant la veille de l'hôte, pas une panne matérielle |
| `fwupd-refresh` en échec | Mineur, inutile dans une VM |

Pour chaque erreur : qu'est-ce que c'est, quel impact, l'environnement l'explique-t-il ?

Constat : un événement daté du 19/10 correspondait en réalité au redémarrage du 21/10, la VM ayant été restaurée avec deux jours de retard. **Une horloge fausse produit des logs faux.**
