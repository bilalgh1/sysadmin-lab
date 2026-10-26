# Linux 1 — Accounts, groups, permissions and sudo

Server: SRV-UBUNTU1 (Ubuntu 24.04 LTS).

## Goal

Two departments (accounting and HR) each share a folder on the server. An operations technician must be able to restart the web server, and nothing else.

## Accounts and groups

| File | Content | Readable by |
|---|---|---|
| `/etc/passwd` | Accounts: name, UID, primary group, home, shell | Everyone |
| `/etc/shadow` | Password hashes (`$6$` = SHA-512), expiry | root and the `shadow` group |
| `/etc/group` | Groups and their secondary members | Everyone |

```bash
sudo groupadd compta
sudo groupadd rh
sudo adduser alice      # same for bob, claire, operateur
sudo usermod -aG compta alice
sudo usermod -aG compta bob
sudo usermod -aG rh claire
getent group compta rh
```

> ⚠️ Always use `usermod -aG`. Without `-a`, the list of secondary groups is **replaced**: run on your own account, you lose the `sudo` group.

Service accounts (`sshd`, `www-data`…) have a UID below 1000 and the `/usr/sbin/nologin` shell: a service runs under a dedicated account nobody can log in with.

## Collaborative folders

A new file's group comes from its creator's **primary group**. Without care, a file created by alice belongs to the `alice` group, and bob cannot edit it.

The **setgid** bit on a directory makes new files inherit the directory's group:

```bash
sudo mkdir -p /srv/partages/compta /srv/partages/rh
sudo chown root:compta /srv/partages/compta
sudo chown root:rh /srv/partages/rh
sudo chmod 2770 /srv/partages/compta /srv/partages/rh
sudo ls -ld /srv/partages/*        # drwxrws---
```

- Owner `root`: a service folder must not belong to a person who may leave.
- `770`: full rights for the group, nothing for others. `2`: setgid (the `s` in `rws`).
- setgid only applies to **new** files; existing files are fixed with `chgrp`.

Reminder: on a directory, `x` means "traverse". Without `x` on a directory, its content is unreachable, whatever the files' own permissions.

## Least-privilege sudo delegation

```bash
sudo visudo -f /etc/sudoers.d/operateur
```

```
operateur ALL=(root) /usr/bin/systemctl restart nginx
```

- Always `visudo` (syntax check), one file per rule in `/etc/sudoers.d/`.
- Absolute path and exact arguments: `/usr/bin/systemctl` without arguments would allow stopping any service.
- `systemctl status` is **not** delegated: it works without sudo, and its pager (`less`) can spawn a root shell. Same logic for editors: delegate file editing with `sudoedit`, never `sudo vim`.

## Tests

| Test | Result |
|---|---|
| alice creates a file in `compta` | Group `compta` ✅ |
| bob edits alice's file | Allowed ✅ |
| claire lists the `compta` folder | `Permission denied` ✅ |
| `sudo -l` as operateur | Only one command: restart nginx ✅ |
| `sudo systemctl stop ssh` as operateur | Refused ✅ |

## Audit

```bash
grep operateur /var/log/auth.log | tail -5
```

The log rebuilds the sequence: `su` to operateur, allowed sudo, `command not allowed` for stopping SSH, session closed. The admin account belongs to the `adm` group, which can read logs without being root; operateur does not.
