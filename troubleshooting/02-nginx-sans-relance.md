# 02 — Site hors ligne après l'arrêt brutal de Nginx

**Type** : provoqué · **Machine** : SRV-UBUNTU1

## Symptôme

Après `sudo kill -9 <PID du master>` : `curl -I http://localhost` → `Couldn't connect to server`.

## Diagnostic

```bash
systemctl status nginx --no-pager
journalctl -u nginx --since "10 min ago"
```

```
nginx.service: Main process exited, code=killed, status=9/KILL
nginx.service: Killing process 1179 (nginx) with signal SIGKILL.
nginx.service: Failed with result 'signal'.
```

systemd tue le worker orphelin (nettoyage du cgroup), passe le service en `failed`, et **ne le relance pas**.

## Cause racine

Par défaut, une unité systemd n'a pas de politique de relance.

## Correction

1. Rétablir : `sudo systemctl start nginx`.
2. Empêcher la récidive par une surcharge, sans modifier le fichier du paquet (écrasé à chaque mise à jour) :

```bash
sudo systemctl edit nginx      # contenu : configs/systemd/nginx-override.conf
systemctl cat nginx
```

## Vérification

Incident rejoué :

```
13:07:20  Failed with result 'signal'.
13:07:25  Scheduled restart job, restart counter is at 1.
13:07:25  Started nginx.service
```

`curl -I http://localhost` → `200 OK`. Le `status` affiche la ligne `Drop-In: .../override.conf`.

## Leçons

- `Restart=on-failure` relance après un plantage, mais respecte un arrêt volontaire.
- La relance automatique peut **masquer** des plantages répétés : la coupler à une alerte sur le compteur de redémarrages.
- Garde-fou : après 5 échecs en 10 s, systemd abandonne (voir [incident 07](07-disque-plein.md)).
