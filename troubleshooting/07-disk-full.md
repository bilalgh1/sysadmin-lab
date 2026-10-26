# 07 — Intranet website down, disk full

**Type**: simulated (tabletop exercise) · **Machine**: SRV-UBUNTU1

## Symptom

Ticket: `http://srv-ubuntu1.company.local` has not loaded since this morning.

## Diagnosis

| Step | Command | Result | Conclusion |
|---|---|---|---|
| 1 | `ping srv-ubuntu1.company.local` | Reply from 10.10.20.10 | DNS and network OK |
| 2 | `Invoke-WebRequest http://srv-ubuntu1...` | Unable to connect | HTTP KO → problem on the server |
| 3 | `systemctl status nginx` | `failed`, `No space left on device`, `restart counter is at 5`, `Start request repeated too quickly` | Disk full; automatic restart gave up |
| 4 | `df -h` | `/` at 100 % | Confirmed |
| 5 | `sudo du -h --max-depth=1 /var/log \| sort -h` | `/var/log/nginx` = 5.1 GB | Culprit located |
| 6 | `ls -lh /var/log/nginx/` | `access.log` 5.1 GB, **no archives** | logrotate no longer runs |
| 7 | `sudo tail -n 100000 access.log \| awk '{print $1}' \| sort \| uniq -c \| sort -rn \| head` | 99 % from 10.10.10.100, User-Agent `python-requests` | Looping script on PC-USER1 |
| 8 | `systemctl status logrotate.timer` | `disabled`, `inactive` | Rotation disabled |

## Root causes

1. A Python script on PC-USER1 hits the website in a loop.
2. logrotate disabled: the log grows without limit.

## Fix

```bash
# First keep a summary and a sample of the log (evidence), copied off the server
sudo truncate -s 0 /var/log/nginx/access.log
sudo systemctl start nginx
sudo ufw insert 1 deny from 10.10.10.100       # at the top: otherwise shadowed by "allow 80/tcp"
sudo ufw status numbered
sudo systemctl enable --now logrotate.timer
sudo logrotate -d /etc/logrotate.d/nginx       # dry run
```

- `truncate` rather than `rm`: the file keeps its permissions, and `rm` on a file still held open does not free the space.
- Blocking the IP is **temporary** (it cuts the whole workstation off, and the DHCP address may change): the real fix is stopping the script, after identifying the workstation (`Get-DhcpServerv4Lease`) and the user (4624 events).

## Lessons learned

- `Restart=on-failure` does not fix a persistent cause.
- Do not destroy traces of abnormal activity before analysing them.
- Prevention: monitoring alert at 80 % disk, `limit_req` in Nginx, verified log rotation.
