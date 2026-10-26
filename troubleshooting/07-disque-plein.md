# 07 — Site intranet hors ligne, disque plein

**Type** : simulé (exercice sur table) · **Machine** : SRV-UBUNTU1

## Symptôme

Ticket : la page `http://srv-ubuntu1.company.local` ne s'affiche plus depuis le matin.

## Diagnostic

| Étape | Commande | Résultat | Conclusion |
|---|---|---|---|
| 1 | `ping srv-ubuntu1.company.local` | Réponse de 10.10.20.10 | DNS et réseau OK |
| 2 | `Invoke-WebRequest http://srv-ubuntu1...` | Connexion impossible | HTTP KO → problème sur le serveur |
| 3 | `systemctl status nginx` | `failed`, `No space left on device`, `restart counter is at 5`, `Start request repeated too quickly` | Disque plein ; la relance automatique a abandonné |
| 4 | `df -h` | `/` à 100 % | Confirmé |
| 5 | `sudo du -h --max-depth=1 /var/log \| sort -h` | `/var/log/nginx` = 5,1 Go | Coupable localisé |
| 6 | `ls -lh /var/log/nginx/` | `access.log` 5,1 Go, **aucune archive** | logrotate ne tourne plus |
| 7 | `sudo tail -n 100000 access.log \| awk '{print $1}' \| sort \| uniq -c \| sort -rn \| head` | 99 % depuis 10.10.10.100, User-Agent `python-requests` | Script en boucle depuis PC-USER1 |
| 8 | `systemctl status logrotate.timer` | `disabled`, `inactive` | Rotation désactivée |

## Causes racines

1. Un script Python sur PC-USER1 interroge le site en boucle.
2. logrotate désactivé : le log grossit sans limite.

## Correction

```bash
# Conserver d'abord un résumé et un échantillon du log (preuves), copiés hors du serveur
sudo truncate -s 0 /var/log/nginx/access.log
sudo systemctl start nginx
sudo ufw insert 1 deny from 10.10.10.100       # en tête : sinon masqué par « allow 80/tcp »
sudo ufw status numbered
sudo systemctl enable --now logrotate.timer
sudo logrotate -d /etc/logrotate.d/nginx       # simulation
```

- `truncate` plutôt que `rm` : le fichier garde ses droits, et un `rm` sur un fichier encore ouvert ne libère pas l'espace.
- Le blocage par IP est **temporaire** (il coupe tout le poste, et l'adresse DHCP peut changer) : la vraie correction est d'arrêter le script, après identification du poste (`Get-DhcpServerv4Lease`) et de l'utilisateur (événements 4624).

## Leçons

- `Restart=on-failure` ne corrige pas une cause persistante.
- Ne pas détruire les traces d'une activité anormale avant de l'avoir analysée.
- Prévention : alerte de supervision à 80 % de disque, `limit_req` dans Nginx, rotation des logs vérifiée.
