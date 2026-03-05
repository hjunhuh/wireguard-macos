# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in wireguard-macos, **please do not open a public issue**.

Instead, report it privately:

1. **GitHub Security Advisories** (preferred): Go to the [Security tab](https://github.com/hjunhuh/wireguard-macos/security/advisories/new) and create a new advisory
2. **Email**: Contact the maintainer directly through GitHub

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix**: As soon as possible, depending on severity

### Scope

This project generates and manages WireGuard private keys, configures system-level networking (pfctl, launchd), and runs with elevated privileges. Security issues in any of these areas are taken seriously.

Out of scope:
- Vulnerabilities in WireGuard itself (report to [wireguard.com](https://www.wireguard.com/))
- Vulnerabilities in macOS or Homebrew
