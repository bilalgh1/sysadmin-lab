# 04 — Perte de l'accès SSH

**Type** : réel · **Machine** : SRV-UBUNTU1

## Symptôme

Après modification de la configuration SSH : `Job for ssh.service failed because the control process exited with error code`. La session en cours survit, mais aucune nouvelle connexion n'est possible.

## Chronologie

1. Le fichier `/etc/ssh/sshd_config.d/01-hardening.conf` est collé dans nano à travers la session SSH : le premier caractère de chaque ligne est corrompu (`PPermitRootLogin`, `AAllowUsers`…).
2. `sudo sshd -t` signale **6 options invalides**.
3. Le service est redémarré malgré tout → `ssh.service` en échec.
4. Une commande de correction collée sur plusieurs lignes est tronquée : `sudo tee /etc/ssh/sshd_config` s'exécute sur le **fichier principal**, qui est vidé, puis attend une saisie (gel apparent de la session).

## Récupération par l'accès hors bande

Session SSH abandonnée, réparation depuis la **console VirtualBox** (équivalent d'un iDRAC, iLO ou console série) :

```bash
sudo cp /usr/share/openssh/sshd_config /etc/ssh/sshd_config      # modèle d'origine
sudo nano /etc/ssh/sshd_config.d/01-hardening.conf               # retapé au clavier
sudo mkdir -p /run/sshd                                          # dossier d'exécution supprimé avec le service
sudo sshd -t && sudo systemctl restart ssh
sudo sshd -T | grep -iE "passwordauthentication|permitrootlogin|allowusers|maxauthtries"
```

## Vérification

| Test | Résultat |
|---|---|
| Connexion par clé | ✅ |
| Connexion par mot de passe forcée | `Permission denied (publickey)` ✅ |
| Connexion d'alice | `Permission denied (publickey)` ✅ |

## Leçons

- **Ne jamais redémarrer un service dont le test de configuration échoue.** Enchaîner : `sshd -t && systemctl restart ssh`.
- Avant de toucher à SSH ou au pare-feu : garder une session ouverte et vérifier l'accès hors bande.
- Éviter les collages multi-lignes dans un terminal peu fiable ; préférer une commande sur une ligne (`printf '%s\n' ... | sudo tee fichier`).
- `/run` est en mémoire et recréé par les services : un service tombé peut laisser des dépendances manquantes.
