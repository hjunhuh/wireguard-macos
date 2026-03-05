# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- GitHub Actions CI with ShellCheck and shfmt
- Issue and PR templates
- Contributing guide, Code of Conduct, Security policy
- Comparison table in README (vs wg-easy, PiVPN, manual setup)

## [1.0.0] - 2026-03-05

### Added
- One-command WireGuard server setup for macOS (`install.sh`)
- Interactive configuration (endpoint, VPN subnet, DNS, WAN interface)
- NAT via `pfctl` anchors — survives macOS updates
- Auto-start on boot via `launchd`
- Client management with QR code generation (`client.sh`)
- PresharedKey support for post-quantum security
- Duplicate client detection and IP range validation
- Server status script (`status.sh`)
- Real-time monitoring dashboard with per-client bandwidth (`monitor.sh`)
- Clean uninstaller (`remove.sh`)
- Apple Silicon and Intel Mac support
- Homebrew bash wrapper to avoid macOS bash 3.2 issues

[Unreleased]: https://github.com/hjunhuh/wireguard-macos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hjunhuh/wireguard-macos/releases/tag/v1.0.0
