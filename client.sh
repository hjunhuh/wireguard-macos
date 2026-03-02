#!/bin/zsh

# ============================================================
# WireGuard Add Client Script (Apple Silicon compatible)
# Usage: ./client.sh [client_name]
#        (no sudo required, will prompt when needed)
# ============================================================

set -e

# --- Detect architecture ---
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

WG_DIR="${BREW_PREFIX}/etc/wireguard"
WG_BIN="${BREW_PREFIX}/bin/wg"

# --- Client name ---
if [[ -z "$1" ]]; then
    read "CLIENT_NAME?Enter client name (e.g. iphone, macbook): "
else
    CLIENT_NAME="$1"
fi

if [[ -z "${CLIENT_NAME}" ]]; then
    echo "[!] Client name is empty. Aborting."
    exit 1
fi

# --- Check server setup exists ---
if [[ ! -f "${WG_DIR}/server_public.key" ]]; then
    echo "[!] Server keys not found. Run install.sh first."
    exit 1
fi

# --- Check for duplicate client name ---
CLIENT_DIR="${WG_DIR}/clients/${CLIENT_NAME}"
if [[ -d "${CLIENT_DIR}" ]]; then
    echo "[!] Client '${CLIENT_NAME}' already exists."
    echo "    Directory: ${CLIENT_DIR}"
    echo "    To remove an existing client, use remove-client.sh."
    exit 1
fi

# --- Load keys and variables ---
SERVER_PUBKEY=$(cat "${WG_DIR}/server_public.key")
ENDPOINT=$(cat "${WG_DIR}/endpoint.var")
DNS=$(cat "${WG_DIR}/dns.var")
VPN_SUBNET=$(cat "${WG_DIR}/vpn_subnet.var")
LAST_IP=$(cat "${WG_DIR}/last_used_ip.var")

# Assign new IP
NEXT_IP=$((LAST_IP + 1))
if [[ ${NEXT_IP} -gt 254 ]]; then
    echo "[!] IP address range exhausted (max 253 clients)."
    exit 1
fi
CLIENT_IP="${VPN_SUBNET}${NEXT_IP}"
echo "${NEXT_IP}" > "${WG_DIR}/last_used_ip.var"

# --- Generate client keys ---
CLIENT_PRIVKEY=$( ${WG_BIN} genkey )
CLIENT_PUBKEY=$( echo "${CLIENT_PRIVKEY}" | ${WG_BIN} pubkey )
CLIENT_PSK=$( ${WG_BIN} genpsk )

# Create client directory
mkdir -p "${CLIENT_DIR}"

echo "${CLIENT_PRIVKEY}" > "${CLIENT_DIR}/privatekey"
echo "${CLIENT_PUBKEY}" > "${CLIENT_DIR}/publickey"
echo "${CLIENT_PSK}" > "${CLIENT_DIR}/presharedkey"
echo "${CLIENT_IP}" > "${CLIENT_DIR}/ip"
chmod 600 "${CLIENT_DIR}"/*

# --- Add peer to server wg0.conf ---
cat >> "${WG_DIR}/wg0.conf" << EOF

# ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUBKEY}
PresharedKey = ${CLIENT_PSK}
AllowedIPs = ${CLIENT_IP}/32
EOF

# --- Generate client config file ---
cat > "${CLIENT_DIR}/${CLIENT_NAME}.conf" << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVKEY}
Address = ${CLIENT_IP}/32
DNS = ${DNS}

[Peer]
PublicKey = ${SERVER_PUBKEY}
PresharedKey = ${CLIENT_PSK}
Endpoint = ${ENDPOINT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# --- Apply live if WireGuard is running ---
# On macOS, interface is utunN, not wg0. Check all WG interfaces.
if sudo ${WG_BIN} show > /dev/null 2>&1; then
    echo "[*] Adding peer to running server..."
    sudo ${WG_BIN} set wg0 peer "${CLIENT_PUBKEY}" \
        preshared-key "${CLIENT_DIR}/presharedkey" \
        allowed-ips "${CLIENT_IP}/32"
    echo "[*] Applied live (no restart needed)"
else
    echo "[*] Server is not running. Changes will apply on next start."
fi

# --- Display QR code ---
echo ""
echo "============================================================"
echo "  Client '${CLIENT_NAME}' added successfully"
echo "============================================================"
echo ""
echo "  VPN IP:      ${CLIENT_IP}"
echo "  Config file: ${CLIENT_DIR}/${CLIENT_NAME}.conf"
echo ""

if command -v qrencode > /dev/null 2>&1; then
    echo "  Scan this QR code with the WireGuard app:"
    echo ""
    qrencode -t ansiutf8 < "${CLIENT_DIR}/${CLIENT_NAME}.conf"
    echo ""
else
    echo "  [!] qrencode not found. Cannot display QR code."
    echo "      Install with: brew install qrencode"
fi

echo "============================================================"
