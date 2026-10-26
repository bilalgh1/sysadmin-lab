# Command cheat sheet

## Linux

| Need | Command |
|---|---|
| Who am I, my groups | `whoami`, `id` |
| Group details | `getent group compta` |
| Add to a group | `sudo usermod -aG <group> <user>` |
| Folder permissions | `ls -ld <folder>` |
| Allowed sudo rules | `sudo -l` |
| Edit a sudo rule | `sudo visudo -f /etc/sudoers.d/<name>` |
| IP addresses, routes | `ip -br a`, `ip route` |
| DNS in use, resolution | `resolvectl status`, `resolvectl query <name>` |
| Query a given DNS server | `dig @<server> <name>` |
| Time and NTP | `timedatectl` |
| Service status | `systemctl status <svc> --no-pager` |
| Running / enabled at boot | `systemctl is-active`, `systemctl is-enabled` |
| Running services | `systemctl list-units --type=service --state=running` |
| Override a unit | `sudo systemctl edit <svc>`, `systemctl cat <svc>` |
| Timers | `systemctl list-timers` |
| Service logs | `journalctl -u <svc> --since today` |
| Boot errors | `journalctl -b -p err` |
| Follow a log | `tail -f <file>` |
| Read a compressed log | `zcat -f <file>*` |
| Disk space | `df -h` |
| What uses the space | `sudo du -h --max-depth=1 /var/log \| sort -h` |
| Processes | `ps -o user,pid,ppid,cmd -C <name>` |
| Updates | `sudo apt update`, `apt list --upgradable`, `sudo apt upgrade` |
| Reboot required? | `cat /var/run/reboot-required.pkgs` |
| Test sshd | `sudo sshd -t`, `sudo sshd -T` |
| Firewall | `sudo ufw status numbered`, `sudo ufw insert 1 ...` |
| Apply network config | `sudo netplan try` |

## Windows / PowerShell

| Need | Command |
|---|---|
| IP configuration | `ipconfig /all`, `ipconfig /release`, `ipconfig /renew` |
| DNS resolution | `nslookup <name>`, `Resolve-DnsName <name> -Server <ip>` |
| Locate a DC | `nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain>` |
| Test a port | `Test-NetConnection <ip> -Port <port>` |
| Windows edition | `Get-ComputerInfo \| Select WindowsProductName, WindowsEditionId` |
| Join / rename | `Add-Computer`, `Rename-Computer -DomainCredential` |
| Domain join log | `Get-Content C:\Windows\debug\NetSetup.LOG -Tail 30` |
| Secure channel | `Test-ComputerSecureChannel [-Repair]` |
| User and groups | `whoami`, `whoami /groups` |
| Authenticating DC | `$env:LOGONSERVER` |
| Kerberos tickets | `klist` |
| AD user | `Get-ADUser <login> -Properties *` |
| User's groups | `Get-ADUser <login> -Properties MemberOf` |
| Group members | `Get-ADGroupMember <group>` |
| Unlock | `Unlock-ADAccount <login>` |
| Password policy | `Get-ADDefaultDomainPasswordPolicy` |
| Apply / read GPOs | `gpupdate /force`, `gpresult /r` |
| DNS forwarders | `Get-DnsServerForwarder` |
| DHCP leases | `Get-DhcpServerv4Lease -ScopeId <network>` |
| Time service | `w32tm /query /source`, `w32tm /query /status` |
| NTFS permissions | `icacls <path>` |
| Shares | `Get-SmbShare`, `Get-SmbShareAccess <name>` |
| Backups | `wbadmin get versions` |
| Security events | `Get-WinEvent -FilterHashtable @{LogName='Security'; Id=<id>}` |
| Help | `Get-Help <command> -Examples` |

## Useful security events

| ID | Meaning |
|---|---|
| 4624 / 4625 | Successful / failed logon |
| 4740 | Account locked out |
| 4728 / 4729 | Member added / removed from a security-enabled global group |
| 4732 / 4733 | Member added / removed from a security-enabled local group |
