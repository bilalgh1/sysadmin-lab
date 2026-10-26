# Linux 4 — SSH durci et pare-feu local

## Authentification par clé

La clé privée reste sur le poste client ; seule la clé publique est copiée sur le serveur. Le serveur envoie un défi que seule la clé privée peut résoudre : aucun mot de passe ne circule.

```powershell
# Poste client (ici le DC, faute de poste d'administration — à proscrire en production)
ssh-keygen -t ed25519            # Entrée pour l'emplacement par défaut, puis phrase de passe
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh user@srv-ubuntu1.company.local "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

- La phrase de passe chiffre la clé privée sur le disque.
- Droits `700` / `600` obligatoires : sinon SSH refuse d'utiliser les clés.
- L'empreinte du serveur, acceptée à la première connexion, protège contre l'interception.

## Durcissement de sshd

Fichier : [`configs/ssh/01-hardening.conf`](../configs/ssh/01-hardening.conf) → `/etc/ssh/sshd_config.d/`.

| Paramètre | Effet |
|---|---|
| `PermitRootLogin no` | Connexion nominative, puis sudo : chaque action est attribuée |
| `PasswordAuthentication no`, `KbdInteractiveAuthentication no` | Clé uniquement |
| `AllowUsers user` | Seul le compte d'administration peut se connecter |
| `MaxAuthTries 3` | Coupe la connexion après 3 échecs |
| `X11Forwarding no` | Pas de renvoi graphique |

Pour sshd, **la première valeur lue l'emporte**, et les fichiers de `sshd_config.d/` sont lus par ordre alphabétique. Le préfixe `01-` passe avant un éventuel `50-cloud-init.conf` contenant `PasswordAuthentication yes`.

```bash
sudo sshd -t && sudo systemctl restart ssh      # ne jamais redémarrer si le test échoue
sudo sshd -T | grep -iE "passwordauthentication|permitrootlogin|allowusers|maxauthtries"
```

Tests depuis le client :

| Commande | Résultat |
|---|---|
| `ssh user@srv-ubuntu1.company.local` | Phrase de passe de la clé, connexion ✅ |
| `ssh -o PubkeyAuthentication=no user@...` | `Permission denied (publickey)` ✅ |
| `ssh alice@...` | `Permission denied (publickey)` ✅ |

Cette étape a provoqué une perte d'accès SSH : [incident 04](../troubleshooting/04-perte-acces-ssh.md).

## Pare-feu ufw

Refus par défaut en entrée, puis ouverture du strict nécessaire. **Les règles d'autorisation sont ajoutées avant l'activation**, sinon la session en cours est coupée.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 10.10.20.20 to any port 22 proto tcp      # provisoire : administration depuis le DC
sudo ufw allow from 10.10.30.0/24 to any port 22 proto tcp    # réseau IT / Admin
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status verbose
```

Le DC et le serveur Linux étant sur le même segment, leur trafic ne traverse pas OPNsense : seul le pare-feu local peut le filtrer.

ufw applique ses règles **dans l'ordre**. Une règle de blocage ajoutée après `allow 80/tcp` n'aurait aucun effet sur le port 80 : on l'insère en tête avec `sudo ufw insert 1 ...`.

## Réduction de surface

```bash
echo "server_tokens off;" | sudo tee /etc/nginx/conf.d/security.conf
sudo nginx -t && sudo systemctl reload nginx
curl -I http://localhost          # Server: nginx (sans numéro de version)
sudo systemctl disable --now ModemManager
```
