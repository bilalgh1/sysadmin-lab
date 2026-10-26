# Troubleshooting method

## Steps

1. **Observe**: exact symptom, since when, who is affected, what changed recently.
2. **Eliminate layer by layer**: interface → gateway → network by IP → DNS → service → permissions. Only move on once the current layer is validated.
3. **Compare**: what works and what does not (two users, two machines, before / after).
4. **Read the logs**: they often contain the exact cause (`journalctl`, `NetSetup.LOG`, Event Viewer).
5. **Form a hypothesis and verify it** before acting. A plausible hypothesis is not a cause.
6. **Fix the cause, not the symptom.**
7. **Verify** the fix works, ideally by replaying the incident.
8. **Document**: symptom, diagnosis, cause, fix, verification, lessons.

## Reflexes

- Before every command: **which machine, which account?** (read the prompt).
- Before any destructive or irreversible action: check, read, **then** act.
- Test a configuration before reloading a service: `sshd -t &&`, `nginx -t &&`.
- Keep a fallback access before touching remote access.
- Look at **where** an answer comes from, not only whether there is one (`Data from: synthetic`).
- Fix the **first** error in a series: the following ones are often cascading effects.
- Preserve traces of abnormal behaviour before cleaning up.

## Example: "the website is down"

| Test | If OK | If KO |
|---|---|---|
| Name resolution | Check the network | DNS problem |
| Ping the address | Check the service | Network, firewall or machine off |
| Port 80 (`Test-NetConnection -Port 80`, `curl`) | Application problem | Service stopped or port filtered |
| `systemctl status` + logs | — | Cause in the error message |
