# Linux 3 — Patch management

## Inventory

```bash
sudo apt update
apt list --upgradable
apt list --upgradable 2>/dev/null | grep -c security
apt list --upgradable 2>/dev/null | grep linux-image
cat /etc/apt/apt.conf.d/20auto-upgrades
```

Finding: **69 pending updates, 56 of them security patches** (openssh, openssl, sudo, systemd, kernel), although automatic updates were enabled.

| Command | Effect |
|---|---|
| `apt update` | Refreshes the package list, installs nothing |
| `apt upgrade` | Installs new versions without removing packages |
| `apt full-upgrade` | May add or remove packages |

## Why nothing was installed

Full investigation: [incident 03](../troubleshooting/03-updates-blocked-by-battery.md).

The `apt-daily-upgrade` service carries `ConditionACPower=true`, and unattended-upgrades checks the power source itself. The VM saw the host laptop's battery (`/sys/class/power_supply/AC/online = 0`) and skipped every run.

Fixes, without touching package-owned files:
- [`configs/systemd/apt-daily-upgrade-override.conf`](../configs/systemd/apt-daily-upgrade-override.conf) via `sudo systemctl edit apt-daily-upgrade.service`
- [`configs/apt/51unattended-upgrades-local`](../configs/apt/51unattended-upgrades-local) in `/etc/apt/apt.conf.d/` (read after the original `50-` file)

Check without installing anything:

```bash
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -iE "battery|will be upgraded"
```

## Maintenance window

1. **Rollback plan**: VM snapshot (`avant-patch-2026-10-22`).
2. **Apply**: `sudo apt update && sudo apt upgrade`, read the summary, keep locally modified config files.
3. **Restarts**: `needrestart` restarts affected services; the new kernel and some services (dbus, logind) require a full reboot (`/var/run/reboot-required.pkgs`).
4. **Checks**:

```bash
uname -r                          # 6.8.0-147-generic
systemctl --failed --no-pager     # 0 failed units
curl -I http://localhost          # 200 OK
apt list --upgradable             # empty
```

5. **Cleanup**: delete the snapshot (a snapshot is not a backup and slows the VM down).

Errors met during the window:
- `404 Not Found`: stale package list → always run `apt update` right before `apt upgrade`.
- `Release file ... is not valid yet`: VM clock behind after restoring a saved state → `sudo systemctl restart systemd-timesyncd`.

## Takeaways

- Enabling automatic updates is not enough: check that they are actually applied.
- A kernel patch is only active after a reboot.
- A major release upgrade (24.04 → 26.04) is a project, not a patch: not applied.
- `xz-utils 5.6.1+really5.4.5`: trace of the rollback after the 2024 xz backdoor (supply chain attack).
