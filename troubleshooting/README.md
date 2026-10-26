# Troubleshooting

Each write-up follows the same structure: **symptom → diagnosis → root cause → fix → verification → lessons learned**.

| # | Incident | Type |
|---|---|---|
| [01](01-dns-ntp.md) | `apt` failing and wrong clock | Real |
| [02](02-nginx-no-restart.md) | Website down after Nginx was killed | Triggered |
| [03](03-updates-blocked-by-battery.md) | 56 security patches never installed | Real |
| [04](04-lost-ssh-access.md) | Lost SSH access | Real |
| [05](05-domain-join-windows-home.md) | Domain join refused | Real |
| [06](06-account-lockout.md) | User account locked out | Real |
| [07](07-disk-full.md) | Website down, disk full | Simulated |
| [08](08-share-access-group.md) | User lost access to the share | Simulated |
| [09](09-trust-relationship.md) | Broken trust relationship | Simulated |

- **Real**: happened while building the lab.
- **Triggered**: caused on purpose to test a behaviour.
- **Simulated**: tabletop exercise with simulated command output; not reproduced in the lab.

Shared method: [../docs/troubleshooting-method.md](../docs/troubleshooting-method.md)
