# Good First Issues

These are self-contained tasks ideal for first-time contributors. Each one is a single PR with clear scope.

## Documentation

1. **Add Japanese README** — Translate `README.md` to `README.ja.md`
2. **Add Chinese README** — Translate `README.md` to `README.zh-CN.md`
3. **Add Korean README** — Translate `README.md` to `README.ko.md`
4. **Add asciinema demo** — Record install + client + monitor flow with [asciinema](https://asciinema.org)

## Scripts

5. **Add `--help` flag to all scripts** — Print usage when `--help` or `-h` is passed
6. **Add `--version` flag** — Print current version from a `VERSION` file
7. **Color output toggle** — Add `--no-color` flag to `monitor.sh` and `status.sh`
8. **Client removal** — Add `client.sh --remove <name>` to delete a peer
9. **List clients** — Add `client.sh --list` to show all registered clients

## Quality

10. **Add BATS tests** — Write [bats-core](https://github.com/bats-core/bats-core) tests for argument parsing and validation logic
11. **Add editorconfig** — Create `.editorconfig` for consistent formatting
12. **Man page** — Create a man page for the main commands
