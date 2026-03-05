# wireguard-macos v1.0.0

The first stable release of wireguard-macos — the easiest way to run a WireGuard VPN server on macOS.

## Highlights

- **One-command setup** — `./install.sh` handles everything: Homebrew packages, key generation, NAT, auto-start
- **Apple Silicon native** — Correctly handles `/opt/homebrew` paths for M1/M2/M3/M4/M5 Macs
- **NAT that survives macOS updates** — Uses `pfctl` anchors instead of editing `/etc/pf.conf`
- **Auto-start on boot** — `launchd` service with the correct Homebrew bash path
- **Client management** — Add clients with QR codes for instant mobile setup
- **Post-quantum security** — PresharedKey support on all client connections
- **Live monitoring** — Real-time dashboard with per-client bandwidth tracking

## What's included

| Script | Purpose |
| --- | --- |
| `install.sh` | Interactive server setup |
| `client.sh` | Add VPN clients with QR codes |
| `status.sh` | Server status overview |
| `monitor.sh` | Real-time monitoring dashboard |
| `remove.sh` | Clean uninstaller |

## Requirements

- macOS 13 (Ventura) or later
- Homebrew
- Router with UDP port forwarding

## Quick start

```bash
git clone https://github.com/hjunhuh/wireguard-macos.git
cd wireguard-macos
./install.sh
```

See the [README](https://github.com/hjunhuh/wireguard-macos#readme) for full documentation.
