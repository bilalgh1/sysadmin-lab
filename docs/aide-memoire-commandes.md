# Aide-mémoire des commandes

## Linux

| Besoin | Commande |
|---|---|
| Qui suis-je, mes groupes | `whoami`, `id` |
| Infos sur un groupe | `getent group compta` |
| Ajouter à un groupe | `sudo usermod -aG <groupe> <user>` |
| Droits d'un dossier | `ls -ld <dossier>` |
| Règles sudo autorisées | `sudo -l` |
| Éditer une règle sudo | `sudo visudo -f /etc/sudoers.d/<nom>` |
| Adresses IP, routes | `ip -br a`, `ip route` |
| DNS utilisé, résolution | `resolvectl status`, `resolvectl query <nom>` |
| Interroger un DNS précis | `dig @<serveur> <nom>` |
| Heure et NTP | `timedatectl` |
| État d'un service | `systemctl status <svc> --no-pager` |
| Actif / au démarrage | `systemctl is-active`, `systemctl is-enabled` |
| Services en cours | `systemctl list-units --type=service --state=running` |
| Surcharger une unité | `sudo systemctl edit <svc>`, `systemctl cat <svc>` |
| Timers | `systemctl list-timers` |
| Logs d'un service | `journalctl -u <svc> --since today` |
| Erreurs du démarrage | `journalctl -b -p err` |
| Suivre un log | `tail -f <fichier>` |
| Lire un log compressé | `zcat -f <fichier>*` |
| Espace disque | `df -h` |
| Qui consomme | `sudo du -h --max-depth=1 /var/log \| sort -h` |
| Processus | `ps -o user,pid,ppid,cmd -C <nom>` |
| Mises à jour | `sudo apt update`, `apt list --upgradable`, `sudo apt upgrade` |
| Redémarrage requis ? | `cat /var/run/reboot-required.pkgs` |
| Tester sshd | `sudo sshd -t`, `sudo sshd -T` |
| Pare-feu | `sudo ufw status numbered`, `sudo ufw insert 1 ...` |
| Appliquer le réseau | `sudo netplan try` |

## Windows / PowerShell

| Besoin | Commande |
|---|---|
| Configuration IP | `ipconfig /all`, `ipconfig /release`, `ipconfig /renew` |
| Résolution DNS | `nslookup <nom>`, `Resolve-DnsName <nom> -Server <ip>` |
| Localiser un DC | `nslookup -type=SRV _ldap._tcp.dc._msdcs.<domaine>` |
| Tester un port | `Test-NetConnection <ip> -Port <port>` |
| Édition de Windows | `Get-ComputerInfo \| Select WindowsProductName, WindowsEditionId` |
| Joindre / renommer | `Add-Computer`, `Rename-Computer -DomainCredential` |
| Journal de jonction | `Get-Content C:\Windows\debug\NetSetup.LOG -Tail 30` |
| Canal sécurisé | `Test-ComputerSecureChannel [-Repair]` |
| Utilisateur et groupes | `whoami`, `whoami /groups` |
| DC d'authentification | `$env:LOGONSERVER` |
| Tickets Kerberos | `klist` |
| Utilisateur AD | `Get-ADUser <login> -Properties *` |
| Groupes d'un utilisateur | `Get-ADUser <login> -Properties MemberOf` |
| Membres d'un groupe | `Get-ADGroupMember <groupe>` |
| Déverrouiller | `Unlock-ADAccount <login>` |
| Politique de mots de passe | `Get-ADDefaultDomainPasswordPolicy` |
| Appliquer / lire les GPO | `gpupdate /force`, `gpresult /r` |
| Redirecteurs DNS | `Get-DnsServerForwarder` |
| Baux DHCP | `Get-DhcpServerv4Lease -ScopeId <réseau>` |
| Service de temps | `w32tm /query /source`, `w32tm /query /status` |
| Permissions NTFS | `icacls <chemin>` |
| Partages | `Get-SmbShare`, `Get-SmbShareAccess <nom>` |
| Sauvegardes | `wbadmin get versions` |
| Événements de sécurité | `Get-WinEvent -FilterHashtable @{LogName='Security'; Id=<id>}` |
| Aide | `Get-Help <commande> -Examples` |

## Événements de sécurité utiles

| ID | Signification |
|---|---|
| 4624 / 4625 | Ouverture de session réussie / échouée |
| 4740 | Compte verrouillé |
| 4728 / 4729 | Membre ajouté / retiré d'un groupe global de sécurité |
| 4732 / 4733 | Membre ajouté / retiré d'un groupe local de sécurité |
