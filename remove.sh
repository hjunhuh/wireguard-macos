#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2162

# ============================================================
# WireGuard Uninstall Script (Apple Silicon compatible)
# Usage: sudo ./remove.sh
# ============================================================

if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

WG_DIR="${BREW_PREFIX}/etc/wireguard"
WG_QUICK="${BREW_PREFIX}/bin/wg-quick"
BREW_BASH="${BREW_PREFIX}/bin/bash"
PLIST_PATH="/Library/LaunchDaemons/com.wireguard.wg0.plist"

echo "[!] This will completely remove the WireGuard server."
read "CONFIRM?Continue? (y/N): "
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

# 1. Stop WireGuard
# [FIX] Call wg-quick with Homebrew bash (avoids system bash 3.2)
echo "[1/4] Stopping WireGuard..."
sudo "${BREW_BASH}" "${WG_QUICK}" down "${WG_DIR}/wg0.conf" 2>/dev/null || true

# 2. Remove launchd service
echo "[2/4] Removing auto-start service..."
sudo launchctl bootout system "${PLIST_PATH}" 2>/dev/null || true
sudo rm -f "${PLIST_PATH}"

# 3. Disable IP forwarding (IPv4 + IPv6)
echo "[3/4] Disabling IP forwarding..."
sudo sysctl -w net.inet.ip.forwarding=0 2>/dev/null || true
sudo sysctl -w net.inet6.ip6.forwarding=0 2>/dev/null || true

# 4. Remove config files
echo "[4/4] Removing configuration files..."
read "REMOVE_KEYS?Delete all keys and config files? (y/N): "
if [[ "${REMOVE_KEYS}" == "y" || "${REMOVE_KEYS}" == "Y" ]]; then
    sudo rm -rf "${WG_DIR}"
    echo "  Config files deleted: ${WG_DIR}"
else
    echo "  Config files preserved: ${WG_DIR}"
fi

# Clean up runtime/logs
sudo rm -rf /usr/local/var/run/wireguard 2>/dev/null || true
sudo rm -f /tmp/wireguard-wg0.err /tmp/wireguard-wg0.log
sudo rm -f "${BREW_PREFIX}/var/log/wireguard-wg0.err" "${BREW_PREFIX}/var/log/wireguard-wg0.log"

echo ""
echo "WireGuard removal complete."
echo "  (To also remove the package: brew uninstall wireguard-tools)"
