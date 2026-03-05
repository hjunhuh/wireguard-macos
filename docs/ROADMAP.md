# Roadmap

This document outlines the planned features and improvements for wireguard-macos. Items are prioritized by impact and feasibility.

## v1.1 — Quality of Life

- [ ] `wg` wrapper script — single `wg-macos start|stop|status|add|remove|monitor` command
- [ ] Client removal — `client.sh --remove <name>` to delete a peer cleanly
- [ ] Configuration backup/restore — export and import server state
- [ ] Automatic Homebrew bash detection — skip wrapper if bash 4+ is the default

## v1.2 — Web Dashboard

- [ ] Lightweight web UI for monitoring (single-binary Go server)
- [ ] Real-time peer status, bandwidth, and handshake info
- [ ] Client management through the browser (add/remove/download config)
- [ ] QR code display in browser
- [ ] Optional authentication (basic auth or token)

### Architecture

```
┌──────────────┐     HTTP/WS     ┌──────────────┐
│   Browser    │ ◄─────────────► │   wg-web     │
│  (Dashboard) │                 │  (Go binary)  │
└──────────────┘                 └───────┬───────┘
                                         │
                                    exec wg show
                                    read configs
                                         │
                                 ┌───────▼───────┐
                                 │   WireGuard   │
                                 │   (wg0.conf)  │
                                 └───────────────┘
```

## v1.3 — Extended Platform Support

- [ ] Intel Mac full test coverage and CI
- [ ] Homebrew Formula (`brew install wireguard-macos`)
- [ ] Docker image for the web dashboard
- [ ] Automated DDNS integration (Cloudflare, DuckDNS, No-IP)

## v1.4 — Advanced Networking

- [ ] Split tunneling — per-client `AllowedIPs` configuration
- [ ] Multi-subnet support — multiple VPN networks on one server
- [ ] IPv6 tunnel support
- [ ] DNS-over-HTTPS relay for VPN clients
- [ ] Traffic logging (opt-in) with rotation

## v1.5 — Enterprise Features

- [ ] Multi-server management — central dashboard for multiple Mac servers
- [ ] Client expiration — time-limited access with auto-revocation
- [ ] Bandwidth limits per client
- [ ] SSO integration (OIDC) for web dashboard
- [ ] Audit logging

## Future Ideas

- Native macOS menu bar app
- iOS Shortcut for toggling clients
- Terraform provider for automated deployment
- Ansible role for fleet management

## Contributing

Want to help build any of these features? Check the [issues](https://github.com/hjunhuh/wireguard-macos/issues) labeled `help wanted` or open a discussion with your ideas.
