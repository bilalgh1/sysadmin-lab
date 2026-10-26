# Sysadmin Lab — Enterprise Windows / Linux Infrastructure

Design, administration and troubleshooting of a small enterprise infrastructure: **Active Directory, DNS, DHCP, Group Policy, NTFS shares, a hardened Linux server, patch management, backup and restore**, with every incident encountered documented.

> Built in a VirtualBox lab. All addresses are private; no passwords or secrets are published.
> The lab itself runs in French, so the names of directory objects (OUs, groups, GPOs) are kept as they exist in Active Directory.

---

## Context

I am a cybersecurity engineer building a series of labs to cover the whole infrastructure stack: **network → systems → cloud → IAM → GRC**.

The first project ([network-admin-lab](https://github.com/bilalgh1/network-admin-lab)) set up a segmented network behind an OPNsense firewall. This second project builds on that network to practise day-to-day **systems administration**: deploy, configure, secure, troubleshoot and document. The Active Directory built here will be the foundation of the upcoming IAM project.

## Objectives

- Administer a Linux server: accounts, permissions, services, logs, updates, SSH, host firewall.
- Structure an Active Directory domain following best practices (OUs, groups, AGDLP).
- Automate account creation with PowerShell.
- Serve addresses with Windows DHCP through a relay agent and join a workstation to the domain.
- Apply security and usability Group Policies.
- Set up file shares with least-privilege NTFS permissions.
- Back up **and test the restore**.
- Troubleshoot incidents with a repeatable method, and document them.

## Architecture

```mermaid
flowchart TB
    INET((Internet)) --- FW["OPNsense<br/>firewall, routing, DHCP relay"]
    FW --- LAN["LAN / Users<br/>10.10.10.0/24"]
    FW --- SRV["SERVERS<br/>10.10.20.0/24"]
    FW --- IT["IT / Admin<br/>10.10.30.0/24"]
    LAN --- PC["PC-USER1<br/>Windows 11 Enterprise<br/>domain member"]
    SRV --- DC["DC (WIN-A5T5IRJE99D)<br/>Windows Server<br/>AD DS, DNS, DHCP, file share, backup"]
    SRV --- LNX["SRV-UBUNTU1<br/>Ubuntu 24.04 LTS<br/>Nginx, SSH"]
```

| Machine | Role | Address |
|---|---|---|
| OPNsense | Firewall, inter-network routing, DHCP relay | 10.10.10.1 / 10.10.20.1 / 10.10.30.1 |
| DC | Domain controller for `company.local`, DNS, DHCP, file share, Windows Server Backup | 10.10.20.20 |
| SRV-UBUNTU1 | Nginx web server, SSH administration | 10.10.20.10 |
| PC-USER1 | Windows 11 Enterprise workstation, domain member | DHCP (10.10.10.100-200) |

Details: [architecture/](architecture/README.md)

## Technologies

| Area | Tools |
|---|---|
| Virtualization | VirtualBox |
| Network | OPNsense (firewall, DHCRelay), ufw |
| Windows | Windows Server (AD DS, DNS, DHCP, File Server, Windows Server Backup), Windows 11 Enterprise |
| Linux | Ubuntu Server 24.04 LTS, systemd, journald, apt / unattended-upgrades, OpenSSH, Nginx |
| Automation | PowerShell (ActiveDirectory, GroupPolicy, DhcpServer, SmbShare modules), Bash |
| Troubleshooting | `dig`, `resolvectl`, `nslookup`, `Test-NetConnection`, `journalctl`, `gpresult`, `klist`, `wbadmin`, NetSetup.log, Event Viewer |

## Implementation

### Linux — [linux/](linux/)
- Department users and groups, collaborative folder with **setgid**, **sudo** delegation limited to a single command.
- **systemd** services: Nginx privilege separation, automatic restart through a drop-in override, reading and triaging logs.
- **Patch management**: diagnosis of silently blocked automatic updates, full maintenance window (snapshot, upgrade, kernel reboot, checks).
- **Key-only SSH**, no root login, allow-listed users; **ufw** firewall with default deny; Nginx version hidden; unused services disabled.

### Windows / Active Directory — [windows/](windows/)
- Dedicated **OU** tree, global and domain local groups following **AGDLP**.
- **Idempotent PowerShell script** creating users from a CSV, with no plaintext password.
- **Windows DHCP** authorized in AD, **DHCP relay** on OPNsense, workstation domain join, new computers redirected to their OU.
- **GPOs**: password and lockout policy, user restrictions, screen lock, legal notice banner, network drive targeted by group.
- **File share** with least-privilege NTFS permissions and **access-based enumeration** (ABE).
- **AD Recycle Bin**, **backup** of system state and share, timed **restore test**.

## Security

| Measure | Where |
|---|---|
| Least privilege: scoped sudo, service accounts without shell, unprivileged Nginx workers | Linux |
| SSH: ed25519 key with passphrase, no password, no root, `AllowUsers`, `MaxAuthTries 3` | Linux |
| Host firewall: default deny, SSH restricted to admin networks | Linux |
| Security patches applied and automation verified | Linux |
| Attack surface reduction: unused services disabled, Nginx version hidden | Linux |
| AGDLP: no permission ever granted directly to a user | AD |
| Passwords: 12 characters minimum, lockout after 5 failures | GPO |
| Initial password never stored, change forced at first logon | Script |
| Session lock after 10 minutes, legal notice banner | GPO |
| NTFS inheritance broken, "Modify" instead of "Full control", ABE | Shares |
| DHCP authorized in AD (protection against rogue DHCP servers) | DHCP |
| AD Recycle Bin, system state backup, tested restore | Backup |

## Incidents and troubleshooting — [troubleshooting/](troubleshooting/README.md)

Each incident is documented: symptom, diagnosis, root cause, fix, verification, lessons learned.

| # | Incident | Root cause | Type |
|---|---|---|---|
| 01 | `apt` failing and wrong clock | Server querying a silent DNS, DC without forwarders, clock of restored VMs | Real |
| 02 | Website down after Nginx was killed | No automatic restart by default | Triggered |
| 03 | 56 security patches never installed | "On AC power" condition: the VM saw the host laptop's battery | Real |
| 04 | Lost SSH access | Corrupted config + restart despite a failed config test | Real |
| 05 | Domain join refused | Windows 11 **Home** (cannot join a domain) | Real |
| 06 | User account locked out | Lockout policy + wrong password | Real |
| 07 | Website down, disk full | Unrotated log fed by a looping script | Simulated |
| 08 | User lost access to the share | Removed from the global group | Simulated |
| 09 | Broken trust relationship | Old snapshot → out-of-sync computer account password | Simulated |

*Real: happened while building the lab. Triggered: caused on purpose to test a behaviour. Simulated: tabletop troubleshooting exercise, not reproduced in the lab.*

Method used: [docs/troubleshooting-method.md](docs/troubleshooting-method.md)

## Automation

- [`scripts/powershell/New-Users.ps1`](scripts/powershell/New-Users.ps1): creates AD users from a CSV (idempotent, error handling, password prompted at runtime, splatting).
- OUs, groups, GPOs, DHCP scope and file share all created with PowerShell.
- Linux configuration files versioned in [`configs/`](configs/).

## Results

- A domain user logs on to the workstation, gets a network drive, accesses their department folder and **cannot see** the other departments' folders.
- The user's token contains both their global **and** domain local groups; authentication uses Kerberos with AES-256.
- The Linux server only accepts key-based SSH connections from authorized networks.
- A user deleted by mistake is restored identically (same SID) within seconds; a deleted file is restored in about **5 minutes**.

## Skills gained

- **Linux**: permissions and special bits, sudoers, systemd (units, overrides, timers, signals), journald and logrotate, apt and unattended-upgrades, netplan, systemd-resolved, OpenSSH, ufw.
- **Windows Server / AD**: OUs, group scopes, AGDLP, computer accounts, Kerberos (TGT, service tickets), AD-integrated DNS (SRV records, forwarders, records), time service, DHCP and relay, GPOs and preferences, NTFS and SMB, AD Recycle Bin, Windows Server Backup.
- **Automation**: PowerShell (object pipeline, splatting, error handling, idempotency).
- **Troubleshooting**: layered approach, comparison, log analysis (journald, NetSetup.log, Event Viewer), separating symptoms from root causes.
- **Professional practices**: test before restarting a service, keep a fallback access, never edit package-owned files, check before any destructive action, document.

## Limitations and improvements

| Accepted limitation | In production |
|---|---|
| File share hosted on the DC | Dedicated member file server, with quotas |
| Single DC | At least two DCs (redundancy, replication) |
| Backup on a disk of the same VM (3-2-1 not met) | Separate backup server, offsite and immutable copy, scheduled backups |
| Administration from the DC | Dedicated admin workstation in the IT network |
| Same initial password for everyone | Random, unique password per user |
| `.local` domain | Subdomain of an owned public name (e.g. `ad.company.com`) |
| No monitoring | Alerts on disk, services, restarts, pending patches |
| No LAPS or separate admin accounts | Covered in the IAM project |

## Repository structure

```
├── README.md
├── architecture/          addressing plan, machines, flows
├── linux/                 accounts and permissions, services and logs, updates, SSH and firewall
├── windows/               AD, DHCP and domain join, GPO, shares, backup
├── scripts/powershell/    user creation script + sample CSV
├── configs/               Linux configuration files (SSH, systemd, apt, nginx)
├── troubleshooting/       one file per incident
└── docs/                  troubleshooting method, command cheat sheet
```
