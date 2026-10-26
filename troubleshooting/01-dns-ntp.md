# 01 — `apt` failing and wrong clock

**Type**: real · **Machines**: SRV-UBUNTU1, DC

## Symptoms

- `apt update`: "Temporary failure resolving archive.ubuntu.com".
- Server clock on 26/09 while the actual date was 14/10; `timedatectl`: `NTP service: active` but `System clock synchronized: no`.

## Diagnosis

Walk up the layers in order, and only move on once the current layer is validated:

| Layer | Command | Result |
|---|---|---|
| Interface | `ip -br a` | ✅ `enp0s3` UP, 10.10.20.10/24 |
| Gateway | `ip route`, `ping -c 3 10.10.20.1` | ✅ |
| Internet by IP | `ping -c 3 1.1.1.1` | ✅ |
| DNS | `resolvectl status`, `resolvectl query archive.ubuntu.com` | ❌ |

`resolvectl status` showed the server was querying **10.10.20.1 (OPNsense)**, not the DC as assumed.

Isolation by querying each DNS server directly:

| Command | Result | Meaning |
|---|---|---|
| `dig @10.10.20.1 archive.ubuntu.com` | `timed out` | Nothing listens on OPNsense port 53 |
| `dig @10.10.20.20 archive.ubuntu.com` | `SERVFAIL` | The DC answers but cannot get the answer |
| `dig @1.1.1.1 archive.ubuntu.com` | `NOERROR` | Outbound DNS does cross the firewall |

On the DC: `Get-Service DNS` → `Running`; `Get-DnsServerForwarder` → **no forwarders**; `Resolve-DnsName ... -Server 1.1.1.1` works.

## Root causes

1. The server used OPNsense as its DNS, and OPNsense's DNS did not answer.
2. The DC had no forwarders.
3. NTP must resolve `ntp.ubuntu.com`: **one cause, two symptoms**.

Found while fixing the DC's time: time zone `Pacific Standard Time`, source `Local CMOS Clock` (no sync at all), and VMs restored from a saved state.

## Fixes

```powershell
# DC
Add-DnsServerForwarder -IPAddress 1.1.1.1, 9.9.9.9
Clear-DnsServerCache -Force
Set-TimeZone -Id "Romance Standard Time"
Set-Date -Date (Get-Date -Year 2026 -Month 10 -Day 19 -Hour 14 -Minute 55 -Second 0)   # gap > 48 h
w32tm /config /manualpeerlist:"0.fr.pool.ntp.org,0x8 1.fr.pool.ntp.org,0x8" /syncfromflags:manual /reliable:yes /update
Restart-Service w32time ; w32tm /resync /rediscover
```

```yaml
# SRV-UBUNTU1 — /etc/netplan/01-netcfg.yaml (backup copy in /root)
      nameservers:
        addresses:
          - 10.10.20.20
        search:
          - company.local
```

Applied with `sudo netplan try` (automatic rollback without confirmation).

## Verification

- `apt update` works.
- `resolvectl query win-a5t5irje99d` → `win-a5t5irje99d.company.local` = 10.10.20.20.
- `timedatectl`: `System clock synchronized: yes`.
- DC: `w32tm /query /status` → source `0.fr.pool.ntp.org`, stratum 3.

## Lessons learned

- Check the actual configuration before trusting a hypothesis.
- `timeout`, `REFUSED`, `SERVFAIL` and `NXDOMAIN` do not mean the same thing.
- Fix the cause, not the symptom: setting `1.1.1.1` on the server would have hidden the fault and broken domain name resolution.
- DNS design in a domain: machines → DC → forwarders. The DC is the time reference (Kerberos: 5 min max skew).
- Shut VMs down cleanly instead of saving their state.
