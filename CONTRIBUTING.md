# Contributing to wireguard-macos

First off, thanks for considering contributing! This project aims to be the easiest WireGuard VPN server setup for macOS, and every contribution helps make that a reality.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/hjunhuh/wireguard-macos/issues) first
2. Open a new issue using the **Bug Report** template
3. Include your macOS version, architecture (Apple Silicon / Intel), and full error output

### Suggesting Features

Open an issue using the **Feature Request** template. Describe the problem you're solving and your proposed approach.

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Ensure scripts pass ShellCheck:
   ```bash
   shellcheck -s bash install.sh client.sh status.sh monitor.sh remove.sh
   ```
5. Commit with a descriptive message (`feat: add split tunneling support`)
6. Push to your fork and open a Pull Request

### Commit Message Format

Follow the `type: description` convention:

| Type       | Use for                          |
| ---------- | -------------------------------- |
| `feat`     | New features                     |
| `fix`      | Bug fixes                        |
| `docs`     | Documentation only               |
| `refactor` | Code changes that aren't fixes   |
| `test`     | Adding or updating tests         |
| `chore`    | Maintenance (CI, deps, etc.)     |

### Code Style

- **Shell**: Use `zsh` syntax (the default macOS shell)
- **Indentation**: 4 spaces, no tabs
- **Quoting**: Always quote variables (`"${VAR}"` not `$VAR`)
- **Error handling**: Use `set -e` where appropriate
- **Comments**: Explain *why*, not *what*

### Testing

Before submitting a PR, test your changes on macOS:

- **Apple Silicon** (M1 or later) — primary target
- **Intel Mac** — if possible

Destructive operations (install, remove) should be tested in a clean environment or VM when practical.

## Development Setup

```bash
git clone https://github.com/hjunhuh/wireguard-macos.git
cd wireguard-macos

# Install dev tools
brew install shellcheck shfmt

# Lint
shellcheck -s bash *.sh

# Format check
shfmt -d -i 4 -ci *.sh
```

## Questions?

Open a [Discussion](https://github.com/hjunhuh/wireguard-macos/discussions) for questions, ideas, or anything else.
