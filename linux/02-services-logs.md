# Linux 2 — Hostname, systemd services and logs

## Renaming the server

```bash
sudo hostnamectl set-hostname srv-ubuntu1
sudo nano /etc/hosts          # 127.0.1.1  srv-ubuntu1
sudo reboot                   # check that the name persists
```

Without updating `/etc/hosts`, `sudo` can no longer resolve its own hostname.

As the server is not a domain member, it does not register itself in DNS. Trap encountered: `resolvectl query srv-ubuntu1` answers `127.0.1.1` with `Data from: synthetic`, an answer generated locally. The real test queries the DC:

```bash
dig @10.10.20.20 srv-ubuntu1.company.local      # NXDOMAIN before the record exists
```

```powershell
# On the DC
Add-DnsServerResourceRecordA -ZoneName "company.local" -Name "srv-ubuntu1" -IPv4Address "10.10.20.10"
```

After creation: `NOERROR`, `aa` flag (the DC is authoritative for the zone).

## Processes and privilege separation

```bash
ps -o user,pid,ppid,cmd -C nginx
```

| Process | User | Parent |
|---|---|---|
| master | `root` | PID 1 (systemd) |
| worker | `www-data` | master |

The master needs root to bind port 80 (< 1024). Workers, which handle visitors' requests, have no privileges: an exploited flaw yields `www-data` rights, not root.

| Command | Question |
|---|---|
| `systemctl is-active nginx` | Is it running now? |
| `systemctl is-enabled nginx` | Will it start at next boot? |
| `systemctl list-units --type=service --state=running` | What runs on this server? |

Unused services on a virtual server: ModemManager (disabled), upower, udisks2, multipathd. SSH does not show up: since Ubuntu 22.10 it is **socket-activated** (`ssh.socket`).

## Signals and automatic restart

| Signal | Effect |
|---|---|
| `SIGTERM` (15) | Graceful stop, `kill` default |
| `SIGKILL` (9) | Immediate stop by the kernel |
| `SIGHUP` (1) | Often: reload configuration (`systemctl reload`) |

Experiments:
- Worker killed: the master spawns a new one immediately.
- Master killed with `kill -9`: systemd cleans up the cgroup, the service goes `failed` and **is not restarted**. The website goes down.

Fix with a **drop-in override**, without editing the package's unit file:

```bash
sudo systemctl edit nginx
```

Content: [`configs/systemd/nginx-override.conf`](../configs/systemd/nginx-override.conf). Check: `systemctl cat nginx`, then replay the incident → `Scheduled restart job, restart counter is at 1`, service back within 5 seconds.

Automatic restarts must be paired with monitoring that alerts on each restart, otherwise crashes go unnoticed. systemd stops restarting after 5 failures within 10 seconds.

## Logs

| Source | Tool |
|---|---|
| systemd services, kernel | `journalctl` |
| Classic text files (`auth.log`, `syslog`) | rsyslog, `/var/log/` |
| Applications | e.g. `/var/log/nginx/access.log`, `error.log` |

```bash
journalctl -u nginx --since today
journalctl --list-boots
journalctl -b -p err --no-pager
tail -f /var/log/nginx/access.log
sudo zcat -f /var/log/unattended-upgrades/unattended-upgrades.log* | tail
```

Error triage applied to the 12 errors of the boot:

| Message | Verdict |
|---|---|
| `vmwgfx ... unsupported hypervisor` | Noise: display driver under VirtualBox |
| `pam_lastlog.so` not found | Known Ubuntu 24.04 bug, no impact |
| `watchdog: BUG: soft lockup` | The VM got no CPU while the host was asleep, not a hardware fault |
| `fwupd-refresh` failed | Minor, useless in a VM |

For each error: what is it, what is the impact, does the environment explain it?

Finding: an event dated 19/10 actually matched the reboot of 21/10, the VM having been restored two days behind. **A wrong clock produces wrong logs.**
