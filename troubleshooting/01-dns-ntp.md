# 01 — `apt` en échec et horloge fausse

**Type** : réel · **Machines** : SRV-UBUNTU1, DC

## Symptômes

- `apt update` : « Erreur temporaire de résolution de archive.ubuntu.com ».
- Horloge du serveur au 26/09 alors qu'on est le 14/10 ; `timedatectl` : `NTP service: active` mais `System clock synchronized: no`.

## Diagnostic

Remonter les couches dans l'ordre, et ne passer à la suivante que si la précédente est validée :

| Couche | Commande | Résultat |
|---|---|---|
| Interface | `ip -br a` | ✅ `enp0s3` UP, 10.10.20.10/24 |
| Passerelle | `ip route`, `ping -c 3 10.10.20.1` | ✅ |
| Internet par IP | `ping -c 3 1.1.1.1` | ✅ |
| DNS | `resolvectl status`, `resolvectl query archive.ubuntu.com` | ❌ |

`resolvectl status` montre que le serveur interroge **10.10.20.1 (OPNsense)**, et non le DC comme supposé.

Isolation en interrogeant chaque serveur DNS directement :

| Commande | Résultat | Signification |
|---|---|---|
| `dig @10.10.20.1 archive.ubuntu.com` | `timed out` | Rien n'écoute sur le port 53 d'OPNsense |
| `dig @10.10.20.20 archive.ubuntu.com` | `SERVFAIL` | Le DC répond mais n'obtient pas la réponse |
| `dig @1.1.1.1 archive.ubuntu.com` | `NOERROR` | Le DNS sortant traverse bien le pare-feu |

Sur le DC : `Get-Service DNS` → `Running` ; `Get-DnsServerForwarder` → **aucun redirecteur** ; `Resolve-DnsName ... -Server 1.1.1.1` fonctionne.

## Causes racines

1. Le serveur utilisait OPNsense comme DNS, et le DNS d'OPNsense ne répondait pas.
2. Le DC n'avait aucun redirecteur.
3. NTP doit résoudre `ntp.ubuntu.com` : **une cause, deux symptômes**.

Découvert en corrigeant l'heure du DC : fuseau `Pacific Standard Time`, source `Local CMOS Clock` (aucune synchronisation), et VM restaurées depuis un état enregistré.

## Corrections

```powershell
# DC
Add-DnsServerForwarder -IPAddress 1.1.1.1, 9.9.9.9
Clear-DnsServerCache -Force
Set-TimeZone -Id "Romance Standard Time"
Set-Date -Date (Get-Date -Year 2026 -Month 10 -Day 19 -Hour 14 -Minute 55 -Second 0)   # écart > 48 h
w32tm /config /manualpeerlist:"0.fr.pool.ntp.org,0x8 1.fr.pool.ntp.org,0x8" /syncfromflags:manual /reliable:yes /update
Restart-Service w32time ; w32tm /resync /rediscover
```

```yaml
# SRV-UBUNTU1 — /etc/netplan/01-netcfg.yaml (copie de sauvegarde dans /root)
      nameservers:
        addresses:
          - 10.10.20.20
        search:
          - company.local
```

Appliqué avec `sudo netplan try` (retour arrière automatique sans confirmation).

## Vérification

- `apt update` fonctionne.
- `resolvectl query win-a5t5irje99d` → `win-a5t5irje99d.company.local` = 10.10.20.20.
- `timedatectl` : `System clock synchronized: yes`.
- DC : `w32tm /query /status` → source `0.fr.pool.ntp.org`, stratum 3.

## Leçons

- Vérifier la configuration réelle avant de croire une hypothèse.
- `timeout`, `REFUSED`, `SERVFAIL` et `NXDOMAIN` n'ont pas la même signification.
- Corriger la cause, pas le symptôme : mettre `1.1.1.1` sur le serveur aurait masqué la panne et cassé la résolution du domaine.
- Schéma DNS d'un domaine : machines → DC → redirecteurs. Le DC est la référence horaire (Kerberos : 5 min d'écart max).
- Éteindre les VM proprement plutôt que d'enregistrer leur état.
