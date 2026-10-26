# 04 — Lost SSH access

**Type**: real · **Machine**: SRV-UBUNTU1

## Symptom

After editing the SSH configuration: `Job for ssh.service failed because the control process exited with error code`. The current session survives, but no new connection is possible.

## Timeline

1. `/etc/ssh/sshd_config.d/01-hardening.conf` is pasted into nano through the SSH session: the first character of each line gets corrupted (`PPermitRootLogin`, `AAllowUsers`…).
2. `sudo sshd -t` reports **6 bad options**.
3. The service is restarted anyway → `ssh.service` fails.
4. A multi-line fix pasted into the terminal gets truncated: `sudo tee /etc/ssh/sshd_config` runs against the **main config file**, which is emptied, then waits for input (apparent session freeze).

## Recovery through out-of-band access

SSH session abandoned, fixed from the **VirtualBox console** (the equivalent of iDRAC, iLO or a serial console):

```bash
sudo cp /usr/share/openssh/sshd_config /etc/ssh/sshd_config      # original template
sudo nano /etc/ssh/sshd_config.d/01-hardening.conf               # typed by hand
sudo mkdir -p /run/sshd                                          # runtime dir removed with the service
sudo sshd -t && sudo systemctl restart ssh
sudo sshd -T | grep -iE "passwordauthentication|permitrootlogin|allowusers|maxauthtries"
```

## Verification

| Test | Result |
|---|---|
| Key-based login | ✅ |
| Forced password login | `Permission denied (publickey)` ✅ |
| alice login | `Permission denied (publickey)` ✅ |

## Lessons learned

- **Never restart a service whose config test fails.** Chain them: `sshd -t && systemctl restart ssh`.
- Before touching SSH or the firewall: keep a session open and check out-of-band access.
- Avoid multi-line pastes in an unreliable terminal; prefer a one-line command (`printf '%s\n' ... | sudo tee file`).
- `/run` lives in memory and is recreated by services: a crashed service can leave missing dependencies behind.
