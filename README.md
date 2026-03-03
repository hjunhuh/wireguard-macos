# wireguard-macos

One-command WireGuard VPN server setup for **macOS on Apple Silicon** (M1/M2/M3/M4/M5).

Sets up a full WireGuard server on a Mac Mini (or any Mac) with interactive configuration, automatic NAT via `pfctl`, auto-start on boot via `launchd`, and QR code generation for mobile clients — all without Docker.

## Why this exists

Running a WireGuard server on macOS has several platform-specific gotchas that existing scripts and guides don't handle well together:

- **Apple Silicon paths** — Homebrew installs to `/opt/homebrew`, not `/usr/local`. Most WireGuard scripts hardcode Intel paths.
- **bash 3.2** — macOS ships with bash 3.2 (2007), but `wg-quick` requires bash 4+. Running `sudo wg-quick` picks up the system bash and fails silently.
- **`utun` interfaces** — macOS maps WireGuard to `utun0`, `utun3`, `utun10`, etc. instead of `wg0`. Tools that check for `wg0` will report the server as stopped when it's actually running.
- **`/etc/pf.conf` fragility** — Editing the system packet filter config directly gets overwritten on macOS updates. The proper approach is `pfctl` anchors.
- **Homebrew + root** — `brew install` refuses to run as root, so `sudo ./install.sh` breaks at the first step.

This project solves all of the above.

## Features

- Automatic Apple Silicon / Intel detection
- Interactive setup (endpoint, VPN subnet, DNS, WAN interface)
- NAT via `pfctl` anchors (survives macOS updates)
- Auto-start on boot via `launchd`
- Client management with QR codes for mobile setup
- PresharedKey for post-quantum security
- Live peer addition without server restart
- Duplicate client detection and IP range validation

## Prerequisites

- macOS 13 (Ventura) or later
- [Homebrew](https://brew.sh) installed
- A router with UDP port forwarding capability
- A static public IP or DDNS hostname

## Quick Start

```bash
git clone https://github.com/hjunhuh/wireguard-macos.git
cd wireguard-macos
chmod +x install.sh client.sh remove.sh status.sh monitor.sh

# Install server (do NOT use sudo — it will ask when needed)
./install.sh
```

The installer will prompt for:

| Prompt        | Example             | Default      |
| ------------- | ------------------- | ------------ |
| Endpoint      | `203.0.113.5:51820` | _(required)_ |
| Server VPN IP | `10.0.10.1`         | `10.0.10.1`  |
| DNS server    | `1.1.1.1`           | `1.1.1.1`    |
| WAN interface | `en0`               | `en0`        |

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

Example output:

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
  PF token:      ...

  Public IP:     ...

  Registered clients:
    - iphone (10.0.10.2)
    - macbook (10.0.10.3)

============================================================
```

### Real-time monitor

```bash
sudo ./monitor.sh
```

A live dashboard that refreshes every 2 seconds, showing:

- Per-client online/offline status, endpoint, and last handshake time
- Per-client RX/TX traffic with real-time bandwidth (KB/s, MB/s)
- Total server traffic and peer summary

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

Press `Ctrl+C` to exit the monitor.

### Uninstall

```bash
sudo ./remove.sh
```

This stops WireGuard, removes the `launchd` service, disables IP forwarding, and optionally deletes all keys and configuration files.

## File Structure

After installation, the following files are created:

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

## Router Configuration

After installation, configure port forwarding on your router:

| Field         | Value                                          |
| ------------- | ---------------------------------------------- |
| External port | The port from your endpoint (default: `51820`) |
| Internal IP   | Your Mac's LAN IP                              |
| Internal port | Same as external                               |
| Protocol      | **UDP**                                        |

## Troubleshooting

### "bash 3 detected" or wg-quick fails silently

macOS ships with bash 3.2. Always invoke `wg-quick` via Homebrew bash:

```bash
sudo /opt/homebrew/bin/bash /opt/homebrew/bin/wg-quick up /opt/homebrew/etc/wireguard/wg0.conf
```

### VPN connects but no internet

```bash
# Check IP forwarding (should be 1)
sysctl net.inet.ip.forwarding

# Check NAT rule exists
sudo pfctl -a com.apple/wireguard -sn
```

If the NAT rule is missing, restart WireGuard (down then up).

### Handshake never completes

1. Verify UDP port forwarding is configured on your router
2. Confirm the endpoint public IP is correct (check with `curl ipinfo.io/ip`)
3. Ensure server and client public keys are correctly cross-referenced
4. Check firewall logs: `cat /tmp/wireguard-wg0.err`

### status.sh shows "STOPPED" but wg-quick says "already exists"

This is expected on macOS. WireGuard maps to `utun` interfaces (e.g., `utun10`), not `wg0`. The current version of `status.sh` uses `sudo wg show` (without an interface name) to correctly detect running interfaces.

### Homebrew refuses to run ("Running Homebrew as root")

Do not use `sudo ./install.sh`. Run `./install.sh` directly — the script calls `sudo` internally only where needed.

## How It Works

### NAT (Network Address Translation)

Instead of editing `/etc/pf.conf` (which gets overwritten on macOS updates), this project uses `pfctl` anchors:

- **PostUp** adds a NAT rule to the `com.apple/wireguard` anchor and saves the pf token
- **PostDown** flushes the anchor rules, releases the pf token, and cleans up

This approach was [proposed by lifepillar](https://github.com/barrowclift/barrowclift.github.io/issues/1) as an improvement to the original [Barrowclift guide](https://barrowclift.me/articles/wireguard-server-on-macos).

### Auto-start

A `launchd` plist is registered at `/Library/LaunchDaemons/com.wireguard.wg0.plist` with `RunAtLoad: true`. It calls `wg-quick up` via Homebrew bash with the correct `PATH` environment variable set, avoiding the bash 3 and path issues entirely.

## License

MIT
