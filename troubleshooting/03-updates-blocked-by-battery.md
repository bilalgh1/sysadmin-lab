# 03 — 56 security patches never installed

**Type**: real · **Machine**: SRV-UBUNTU1

## Symptom

`apt list --upgradable`: 69 pending updates, 56 of them security, although `/etc/apt/apt.conf.d/20auto-upgrades` enables automatic updates.

## Diagnosis

| Step | Command | Finding |
|---|---|---|
| Are the timers running? | `systemctl list-timers apt-daily*` | Yes, triggered at boot |
| What does the tool say? | `tail /var/log/unattended-upgrades/unattended-upgrades.log` | File **empty** |
| What does systemd say? | `journalctl -u apt-daily-upgrade.service` | `skipped because of an unmet condition check (ConditionACPower=true)` since 26/09 |
| What does the VM see? | `ls /sys/class/power_supply/`, `cat .../online` | `AC` and `BAT0`, AC at `0` |
| Archived logs | `sudo zcat .../unattended-upgrades.log.1.gz` | `WARNING System is on battery power, stopping` |

Three hypotheses had been put forward (broken DNS, VM often off, apt lock). **None was right**: only checking the logs revealed the cause.

The "empty" log had been archived by **logrotate**: when a log is empty, look for its `.1`, `.2.gz` versions.

## Root cause

VirtualBox passes the host laptop's battery state to the VM. Two independent checks prevented installation on battery:
1. `ConditionACPower=true` in `apt-daily-upgrade.service`;
2. unattended-upgrades' own check.

## Fix

Both levels, without editing package-owned files:
- [`configs/systemd/apt-daily-upgrade-override.conf`](../configs/systemd/apt-daily-upgrade-override.conf)
- [`configs/apt/51unattended-upgrades-local`](../configs/apt/51unattended-upgrades-local)

## Verification

```bash
systemctl cat apt-daily-upgrade.service      # ConditionACPower= override at the end
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -iE "battery|will be upgraded"
```

The list of packages to upgrade is shown, with no mention of the battery. Patches were then applied during a maintenance window ([linux/03](../linux/03-patch-management.md)).

## Lessons learned

- Enabling automation is not enough: check that it has an effect. Worth monitoring: the number of pending security patches.
- The same rule can be enforced at several levels.
- Do not keep a plausible explanation without confirming it.
