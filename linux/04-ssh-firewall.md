# Linux 4 — Hardened SSH and host firewall

## Key-based authentication

The private key stays on the client; only the public key is copied to the server. The server sends a challenge only the private key can answer: no password ever travels.

```powershell
# Client (here the DC, for lack of an admin workstation — never do this in production)
ssh-keygen -t ed25519            # Enter for the default location, then a passphrase
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh user@srv-ubuntu1.company.local "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

- The passphrase encrypts the private key on disk.
- `700` / `600` permissions are mandatory, otherwise SSH ignores the keys.
- The server fingerprint, accepted on first connection, protects against interception.

## sshd hardening

File: [`configs/ssh/01-hardening.conf`](../configs/ssh/01-hardening.conf) → `/etc/ssh/sshd_config.d/`.

| Setting | Effect |
|---|---|
| `PermitRootLogin no` | Personal login, then sudo: every action is attributable |
| `PasswordAuthentication no`, `KbdInteractiveAuthentication no` | Keys only |
| `AllowUsers user` | Only the admin account can log in |
| `MaxAuthTries 3` | Drops the connection after 3 failures |
| `X11Forwarding no` | No graphical forwarding |

For sshd, **the first value read wins**, and files in `sshd_config.d/` are read in alphabetical order. The `01-` prefix comes before a possible `50-cloud-init.conf` containing `PasswordAuthentication yes`.

```bash
sudo sshd -t && sudo systemctl restart ssh      # never restart if the test fails
sudo sshd -T | grep -iE "passwordauthentication|permitrootlogin|allowusers|maxauthtries"
```

Tests from the client:

| Command | Result |
|---|---|
| `ssh user@srv-ubuntu1.company.local` | Key passphrase, logged in ✅ |
| `ssh -o PubkeyAuthentication=no user@...` | `Permission denied (publickey)` ✅ |
| `ssh alice@...` | `Permission denied (publickey)` ✅ |

This step caused a loss of SSH access: [incident 04](../troubleshooting/04-lost-ssh-access.md).

## ufw firewall

Default deny inbound, then open only what is needed. **Allow rules are added before enabling**, otherwise the current session is cut.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 10.10.20.20 to any port 22 proto tcp      # temporary: administration from the DC
sudo ufw allow from 10.10.30.0/24 to any port 22 proto tcp    # IT / Admin network
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status verbose
```

The DC and the Linux server are on the same segment, so their traffic never crosses OPNsense: only the host firewall can filter it.

ufw evaluates rules **in order**. A deny rule added after `allow 80/tcp` would have no effect on port 80: insert it at the top with `sudo ufw insert 1 ...`.

## Attack surface reduction

```bash
echo "server_tokens off;" | sudo tee /etc/nginx/conf.d/security.conf
sudo nginx -t && sudo systemctl reload nginx
curl -I http://localhost          # Server: nginx (no version number)
sudo systemctl disable --now ModemManager
```
