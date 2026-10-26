# 02 — Website down after Nginx was killed

**Type**: triggered · **Machine**: SRV-UBUNTU1

## Symptom

After `sudo kill -9 <master PID>`: `curl -I http://localhost` → `Couldn't connect to server`.

## Diagnosis

```bash
systemctl status nginx --no-pager
journalctl -u nginx --since "10 min ago"
```

```
nginx.service: Main process exited, code=killed, status=9/KILL
nginx.service: Killing process 1179 (nginx) with signal SIGKILL.
nginx.service: Failed with result 'signal'.
```

systemd kills the orphaned worker (cgroup cleanup), marks the service `failed`, and **does not restart it**.

## Root cause

By default, a systemd unit has no restart policy.

## Fix

1. Restore service: `sudo systemctl start nginx`.
2. Prevent recurrence with a drop-in override, without editing the package's unit file (overwritten on every update):

```bash
sudo systemctl edit nginx      # content: configs/systemd/nginx-override.conf
systemctl cat nginx
```

## Verification

Incident replayed:

```
13:07:20  Failed with result 'signal'.
13:07:25  Scheduled restart job, restart counter is at 1.
13:07:25  Started nginx.service
```

`curl -I http://localhost` → `200 OK`. `status` shows the line `Drop-In: .../override.conf`.

## Lessons learned

- `Restart=on-failure` restarts after a crash but honours a deliberate stop.
- Automatic restarts can **hide** repeated crashes: pair them with an alert on the restart counter.
- Safeguard: after 5 failures in 10 s, systemd gives up (see [incident 07](07-disk-full.md)).
