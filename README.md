<p align="center">
  <h1 align="center">wireguard-macos</h1>
  <p align="center">
    <strong>The easiest way to run a WireGuard VPN server on macOS</strong>
  </p>
  <p align="center">
    One command to set up a full WireGuard server on any Mac — with auto-start, NAT, QR codes, and live monitoring.
  </p>
</p>

<p align="center">
  <a href="https://github.com/hjunhuh/wireguard-macos/stargazers"><img src="https://img.shields.io/github/stars/hjunhuh/wireguard-macos?style=flat&color=yellow" alt="Stars"></a>
  <a href="https://github.com/hjunhuh/wireguard-macos/blob/main/LICENSE"><img src="https://img.shields.io/github/license/hjunhuh/wireguard-macos?color=blue" alt="License"></a>
  <a href="https://github.com/hjunhuh/wireguard-macos/actions/workflows/ci.yml"><img src="https://github.com/hjunhuh/wireguard-macos/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple_Silicon-M1--M5-purple" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/shell-zsh-green" alt="Shell">
</p>

---

## Why wireguard-macos?

Running a WireGuard server on macOS is full of platform-specific traps. Existing scripts and guides fail because they don't handle all of them together:

| Problem | What goes wrong | How we fix it |
| --- | --- | --- |
| **Apple Silicon paths** | Homebrew installs to `/opt/homebrew`, not `/usr/local`. Most scripts hardcode Intel paths. | Auto-detect architecture at install time |
| **bash 3.2** | macOS ships bash 3.2 (2007). `wg-quick` needs bash 4+. `sudo wg-quick` fails silently. | Force Homebrew bash via wrapper |
| **`utun` interfaces** | macOS maps WireGuard to `utun0`, `utun3`, etc. — not `wg0`. Status checks break. | Detect active `utun` dynamically |
| **`/etc/pf.conf` fragility** | Direct edits get overwritten on macOS updates. | Use `pfctl` anchors instead |
| **Homebrew + root** | `brew install` refuses to run as root. `sudo ./install.sh` breaks immediately. | Run as user, `sudo` only where needed |

**wireguard-macos solves all five.** No Docker, no VM, no hacks — just clean shell scripts that work with macOS, not against it.

## Comparison

| Feature | **wireguard-macos** | wg-easy | PiVPN | Manual setup |
| --- | :---: | :---: | :---: | :---: |
| macOS native | **Yes** | No (Docker) | No (Linux) | Partial |
| Apple Silicon | **Yes** | N/A | N/A | Manual |
| One-command install | **Yes** | Yes | Yes | No |
| Auto-start on boot | **Yes** | Docker restart | systemd | Manual |
| NAT survives OS updates | **Yes** | N/A | N/A | No |
| QR codes for mobile | **Yes** | Yes | Yes | Manual |
| Post-quantum preshared keys | **Yes** | No | Optional | Manual |
| Live monitoring dashboard | **Yes** | Web UI | No | No |
| No Docker required | **Yes** | No | Yes | Yes |

## Quick Start

```bash
git clone https://github.com/hjunhuh/wireguard-macos.git
cd wireguard-macos

# Install server (do NOT use sudo — it will ask when needed)
./install.sh
```

The installer will prompt for:

| Prompt | Example | Default |
| --- | --- | --- |
| Endpoint | `203.0.113.5:51820` | _(required)_ |
| Server VPN IP | `10.0.10.1` | `10.0.10.1` |
| DNS server | `1.1.1.1` | `1.1.1.1` |
| WAN interface | `en0` | `en0` |

### Prerequisites

- macOS 13 (Ventura) or later
- [Homebrew](https://brew.sh) installed
- A router with UDP port forwarding capability
- A static public IP or DDNS hostname

## Usage

### Add a client

```bash
./client.sh iphone
./client.sh macbook
```

A QR code is printed to the terminal. Scan it with the [WireGuard app](https://www.wireguard.com/install/) on iOS/Android, or import the generated `.conf` file on desktop clients.

### Start / Stop

> **Important:** Always use the Homebrew bash path. Running `sudo wg-quick` directly uses macOS system bash 3.2, which will fail.

```bash
# Start
sudo /opt/homebrew/bin/bash /opt/homebrew/bin/wg-quick up /opt/homebrew/etc/wireguard/wg0.conf

# Stop
sudo /opt/homebrew/bin/bash /opt/homebrew/bin/wg-quick down /opt/homebrew/etc/wireguard/wg0.conf
```

The server starts automatically on boot via `launchd`, so manual start is only needed the first time.

### Check status

```bash
sudo ./status.sh
```

```
============================================================
  WireGuard Server Status
============================================================

  Status:       RUNNING (interface: utun10)

  interface: utun10
  public key: ...
  private key: (hidden)
  listening port: 51820

  peer: ...
    preshared key: (hidden)
    allowed ips: 10.0.10.2/32

  IP forwarding: ENABLED
  NAT rule:      ACTIVE (nat on en0 inet from 10.0.10.0/24 to any -> (en0))

  Registered clients:
    - iphone (10.0.10.2)
    - macbook (10.0.10.3)

============================================================
```

### Real-time monitor

```bash
sudo ./monitor.sh
```

A live dashboard that refreshes every 2 seconds:

```
============================================================
  WireGuard Monitor                     [2026-03-03 14:32:05]
============================================================

  Interface:  utun10            Port: 51820
  Public Key: aBcDeFgHiJkLmNoPqRsT...
  Uptime:     3d 14h 22m        Peers: 2/3 online

------------------------------------------------------------
  CLIENT        STATUS    ENDPOINT            LAST HANDSHAKE
------------------------------------------------------------
  iphone        ONLINE    203.0.113.50:4921     12s ago
                RX: 145.2 MB (52.3 KB/s)   TX: 1.2 GB (128.7 KB/s)
  macbook       ONLINE    198.51.100.8:51820    45s ago
                RX: 2.3 GB (1.2 MB/s)      TX: 523.4 MB (256.0 KB/s)
  ipad          OFFLINE   --                    3h 12m ago
                RX: 89.1 MB (0 B/s)        TX: 12.3 MB (0 B/s)
------------------------------------------------------------

  TOTALS        RX: 2.5 GB (1.3 MB/s)      TX: 1.7 GB (384.7 KB/s)
  PEERS         3 registered, 2 online, 1 offline

============================================================
  Refresh: 2s | Ctrl+C to exit
============================================================
```

### Uninstall

```bash
sudo ./remove.sh
```

Stops WireGuard, removes the `launchd` service, disables IP forwarding, and optionally deletes all keys and configuration files.

## File Structure

After installation:

```
/opt/homebrew/etc/wireguard/
├── wg0.conf                 # Server config (includes peers)
├── wg0.conf.def             # Backup of server config (no peers)
├── postup.sh                # NAT enable script (pfctl anchor)
├── postdown.sh              # NAT disable + anchor flush
├── wg-quick-sudo.sh         # Homebrew bash wrapper
├── server_public.key
├── server_private.key
├── endpoint.var
├── dns.var
├── vpn_subnet.var
├── wan_interface_name.var
├── last_used_ip.var
└── clients/
    ├── iphone/
    │   ├── iphone.conf      # Client config (share this)
    │   ├── privatekey
    │   ├── publickey
    │   ├── presharedkey
    │   └── ip
    └── macbook/
        └── ...

/Library/LaunchDaemons/
└── com.wireguard.wg0.plist  # Auto-start on boot
```

## How It Works

### NAT (Network Address Translation)

Instead of editing `/etc/pf.conf` (which gets overwritten on macOS updates), this project uses `pfctl` anchors:

- **PostUp** adds NAT + pass rules to the `com.apple/wireguard` anchor and saves the pf token
- **PostDown** flushes the anchor rules, releases the pf token, and removes the subnet route

This approach was [proposed by lifepillar](https://github.com/barrowclift/barrowclift.github.io/issues/1) as an improvement to the original [Barrowclift guide](https://barrowclift.me/articles/wireguard-server-on-macos).

### Auto-start

A `launchd` plist is registered at `/Library/LaunchDaemons/com.wireguard.wg0.plist` with `RunAtLoad: true`. It calls `wg-quick up` via Homebrew bash with the correct `PATH` environment variable set, avoiding the bash 3 and path issues entirely.

## Router Configuration

After installation, configure port forwarding on your router:

| Field | Value |
| --- | --- |
| External port | The port from your endpoint (default: `51820`) |
| Internal IP | Your Mac's LAN IP |
| Internal port | Same as external |
| Protocol | **UDP** |

## Troubleshooting

<details>
<summary><strong>"bash 3 detected" or wg-quick fails silently</strong></summary>

macOS ships with bash 3.2. Always invoke `wg-quick` via Homebrew bash:

```bash
sudo /opt/homebrew/bin/bash /opt/homebrew/bin/wg-quick up /opt/homebrew/etc/wireguard/wg0.conf
```
</details>

<details>
<summary><strong>VPN connects but no internet</strong></summary>

```bash
# Check IP forwarding (should be 1)
sysctl net.inet.ip.forwarding

# Check NAT rule exists
sudo pfctl -a com.apple/wireguard -sn
```

If the NAT rule is missing, restart WireGuard (down then up).
</details>

<details>
<summary><strong>Handshake never completes</strong></summary>

1. Verify UDP port forwarding is configured on your router
2. Confirm the endpoint public IP is correct (`curl ipinfo.io/ip`)
3. Ensure server and client public keys are correctly cross-referenced
4. Check firewall logs: `cat /tmp/wireguard-wg0.err`
</details>

<details>
<summary><strong>status.sh shows "STOPPED" but wg-quick says "already exists"</strong></summary>

macOS maps WireGuard to `utun` interfaces (`utun10`, not `wg0`). `status.sh` uses `sudo wg show` (without an interface name) to correctly detect running interfaces.
</details>

<details>
<summary><strong>Homebrew refuses to run ("Running Homebrew as root")</strong></summary>

Do not use `sudo ./install.sh`. Run `./install.sh` directly — the script calls `sudo` internally only where needed.
</details>

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — Hyeong Jun Huh

## Star History

<a href="https://star-history.com/#hjunhuh/wireguard-macos&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=hjunhuh/wireguard-macos&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=hjunhuh/wireguard-macos&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=hjunhuh/wireguard-macos&type=Date" />
 </picture>
</a>
