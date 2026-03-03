#!/bin/zsh

# ============================================================
# WireGuard Status Check Script
# Usage: sudo ./status.sh
# ============================================================

if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

WG_DIR="${BREW_PREFIX}/etc/wireguard"
WG_BIN="${BREW_PREFIX}/bin/wg"
BREW_BASH="${BREW_PREFIX}/bin/bash"
WG_QUICK="${BREW_PREFIX}/bin/wg-quick"

echo "============================================================"
echo "  WireGuard Server Status"
echo "============================================================"
echo ""

# --- On macOS, WireGuard maps to utunN, not wg0 ---
# Use 'wg show' without interface to detect all running WG interfaces
WG_OUTPUT=$(sudo ${WG_BIN} show 2>/dev/null)

if [[ -n "${WG_OUTPUT}" ]]; then
    WG_IFACE=$(echo "${WG_OUTPUT}" | head -1 | awk '{print $2}')
    echo "  Status:       RUNNING (interface: ${WG_IFACE})"
    echo ""
    echo "${WG_OUTPUT}"
else
    echo "  Status:       STOPPED"
    echo ""
    echo "  To start:"
    echo "    sudo ${BREW_BASH} ${WG_QUICK} up ${WG_DIR}/wg0.conf"
fi

echo ""

# IP forwarding (IPv4)
FWD=$(sysctl -n net.inet.ip.forwarding)
if [[ "${FWD}" == "1" ]]; then
    echo "  IPv4 forwarding: ENABLED"
else
    echo "  IPv4 forwarding: DISABLED"
fi

# IP forwarding (IPv6)
FWD6=$(sysctl -n net.inet6.ip6.forwarding)
if [[ "${FWD6}" == "1" ]]; then
    echo "  IPv6 forwarding: ENABLED"
else
    echo "  IPv6 forwarding: DISABLED"
fi

# PF NAT rules
PF_RULE=$(sudo pfctl -a com.apple/wireguard -sn 2>/dev/null)
if [[ -n "${PF_RULE}" ]]; then
    echo "  NAT rule:      ACTIVE (${PF_RULE})"
else
    echo "  NAT rule:      NONE"
fi

# PF token
TOKEN_FILE="/usr/local/var/run/wireguard/pf_wireguard_token.txt"
if [[ -f "${TOKEN_FILE}" ]]; then
    echo "  PF token:      $(cat ${TOKEN_FILE})"
else
    echo "  PF token:      NONE"
fi

# Public IP
echo ""
echo "  Public IP:     $(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null || echo 'unavailable')"

# Registered clients
echo ""
echo "  Registered clients:"
if [[ -d "${WG_DIR}/clients" ]]; then
    CLIENT_COUNT=0
    for client_dir in "${WG_DIR}/clients"/*/; do
        if [[ -d "${client_dir}" ]]; then
            name=$(basename "${client_dir}")
            ip=$(cat "${client_dir}/ip" 2>/dev/null || echo "?")
            echo "    - ${name} (${ip})"
            CLIENT_COUNT=$((CLIENT_COUNT + 1))
        fi
    done
    if [[ ${CLIENT_COUNT} -eq 0 ]]; then
        echo "    (none)"
    fi
else
    echo "    (none)"
fi

echo ""
echo "============================================================"
