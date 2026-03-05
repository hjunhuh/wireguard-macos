#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2162

# ============================================================
# WireGuard Server Setup Script for macOS (Apple Silicon)
# ============================================================

set -e

# --- Prevent running as root ---
if [[ "$(id -u)" -eq 0 ]]; then
    echo "[!] Do not run this script with sudo."
    echo "    Homebrew cannot run as root."
    echo ""
    echo "    Usage:  ./install.sh"
    echo "    (sudo will be requested automatically where needed)"
    exit 1
fi

# --- Banner ---
echo ""
echo ' __     __     __     ______     ______     ______     __  __     ______     ______     _____    '
echo '/\ \  _ \ \   /\ \   /\  == \   /\  ___\   /\  ___\   /\ \/\ \   /\  __ \   /\  == \   /\  __-.  '
echo '\ \ \/ ".\ \  \ \ \  \ \  __<   \ \  __\   \ \ \__ \  \ \ \_\ \  \ \  __ \  \ \  __<   \ \ \/\ \ '
echo ' \ \__/".~\_\  \ \_\  \ \_\ \_\  \ \_____\  \ \_____\  \ \_____\  \ \_\ \_\  \ \_\ \_\  \ \____- '
echo '  \/_/   \/_/   \/_/   \/_/ /_/   \/_____/   \/_____/   \/_____/   \/_/\/_/   \/_/ /_/   \/____/ '
echo ""
echo "     macOS Server Installer v1.0"
echo ""

# --- Detect Apple Silicon / Intel ---
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

WG_DIR="${BREW_PREFIX}/etc/wireguard"
WG_QUICK="${BREW_PREFIX}/bin/wg-quick"
WG_BIN="${BREW_PREFIX}/bin/wg"
BREW_BASH="${BREW_PREFIX}/bin/bash"

echo "[*] Detected architecture: $(uname -m)"
echo "[*] Homebrew prefix: ${BREW_PREFIX}"
echo ""

# --- 1. Install packages ---
echo "[1/7] Installing WireGuard tools..."
# wireguard-tools automatically installs wireguard-go (userspace driver)
# and bash (wg-quick dependency).
brew install wireguard-tools qrencode

# --- 2. Create working directory ---
echo "[2/7] Creating directories..."
sudo mkdir -p "${WG_DIR}"
sudo chown "$(whoami)":staff "${WG_DIR}"
cd "${WG_DIR}"
umask 077

# --- 3. Generate server keys ---
echo "[3/7] Generating server keys..."
SERVER_PRIVKEY=$( "${WG_BIN}" genkey )
SERVER_PUBKEY=$( echo "${SERVER_PRIVKEY}" | "${WG_BIN}" pubkey )
if [[ -z "${SERVER_PRIVKEY}" || -z "${SERVER_PUBKEY}" ]]; then
    echo "[!] Failed to generate server keys. Is wireguard-tools installed?"
    exit 1
fi
echo "${SERVER_PUBKEY}" > ./server_public.key
echo "${SERVER_PRIVKEY}" > ./server_private.key
echo "  Server public key: ${SERVER_PUBKEY}"

# --- 4. Interactive configuration (zsh compatible) ---
echo ""
echo "[4/7] Server configuration..."

# Endpoint (public IP:port)
read "ENDPOINT?Enter endpoint [public_IP:port] (e.g. 1.2.3.4:51820): "
if [[ -z "${ENDPOINT}" ]]; then
    echo "[!] Endpoint is empty. Aborting."
    exit 1
fi
# Validate endpoint format: IP:PORT or HOSTNAME:PORT
if [[ ! "${ENDPOINT}" =~ :[0-9]+$ ]]; then
    echo "[!] Invalid endpoint format. Expected IP:PORT or HOSTNAME:PORT (e.g. 1.2.3.4:51820)"
    exit 1
fi
echo "${ENDPOINT}" > ./endpoint.var

# Server VPN IP
read "SERVER_IP?Server VPN IP (default: 10.0.10.1): "
if [[ -z "${SERVER_IP}" ]]; then
    SERVER_IP="10.0.10.1"
fi
# Validate IP address format (basic check: four octets 0-255)
if [[ ! "${SERVER_IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "[!] Invalid IP address format: ${SERVER_IP}"
    exit 1
fi
# Extract subnet prefix (e.g. 10.0.10.1 -> 10.0.10.)
VPN_SUBNET=$(echo "${SERVER_IP}" | grep -o -E '([0-9]+\.){3}')
echo "${VPN_SUBNET}" > ./vpn_subnet.var

# DNS
read "DNS?DNS server (default: 1.1.1.1): "
if [[ -z "${DNS}" ]]; then
    DNS="1.1.1.1"
fi
echo "${DNS}" > ./dns.var

# WAN interface
echo ""
echo "  Available network interfaces:"
echo "  ---"
ifconfig -l | tr ' ' '\n' | grep -E '^en[0-9]+$' | while read iface; do
    ip=$(ifconfig "${iface}" 2>/dev/null | grep 'inet ' | awk '{print $2}')
    if [[ -n "${ip}" ]]; then
        echo "    ${iface}: ${ip}"
    fi
done
echo "  ---"
read "WAN_INTERFACE_NAME?WAN interface (default: en0): "
if [[ -z "${WAN_INTERFACE_NAME}" ]]; then
    WAN_INTERFACE_NAME="en0"
fi
echo "${WAN_INTERFACE_NAME}" > ./wan_interface_name.var

# Initialize client counter
echo "1" > ./last_used_ip.var

# --- 5. Generate configuration files ---
echo ""
echo "[5/7] Generating configuration files..."

# Extract port
SERVER_EXTERNAL_PORT=$(echo "${ENDPOINT}" | cut -d':' -f2)

# Generate wg0.conf
cat > "${WG_DIR}/wg0.conf" << EOF
[Interface]
Address = ${SERVER_IP}/24
SaveConfig = false
PrivateKey = ${SERVER_PRIVKEY}
ListenPort = ${SERVER_EXTERNAL_PORT}
PostUp = /usr/sbin/sysctl -w net.inet.ip.forwarding=1
PostUp = /usr/sbin/sysctl -w net.inet6.ip6.forwarding=1
PostUp = ${WG_DIR}/postup.sh
PostDown = ${WG_DIR}/postdown.sh
EOF

# Backup wg0.conf (base template without peers)
cp -f "${WG_DIR}/wg0.conf" "${WG_DIR}/wg0.conf.def"

# --- 6. Generate NAT scripts ---
echo "[6/7] Generating NAT scripts..."

# postup.sh — WAN_INTERFACE_NAME / VPN_SUBNET expanded at install time (unquoted heredoc)
#              WG_IF uses \$ to expand at runtime
cat > "${WG_DIR}/postup.sh" << POSTUP
#!/bin/sh
# WireGuard PostUp: NAT + pass rules + subnet route

mkdir -p /usr/local/var/run/wireguard
chmod 700 /usr/local/var/run/wireguard

# Get the actual utun interface name (macOS assigns utunN dynamically)
WG_IF=\$(cat /var/run/wireguard/wg0.name 2>/dev/null | tr -d '[:space:]')

# Add NAT + pass rules to pfctl anchor + save token
# NAT alone is insufficient — explicit pass rules are needed for forwarded traffic
echo "nat on ${WAN_INTERFACE_NAME} from ${VPN_SUBNET}0/24 to any -> (${WAN_INTERFACE_NAME})
pass quick on \${WG_IF} all
pass quick on ${WAN_INTERFACE_NAME} from ${VPN_SUBNET}0/24 to any" | \\
    pfctl -a com.apple/wireguard -Ef - 2>&1 | \\
    grep 'Token' | \\
    sed 's%Token : \(.*\)%\1%' > /usr/local/var/run/wireguard/pf_wireguard_token.txt
chmod 600 /usr/local/var/run/wireguard/pf_wireguard_token.txt

# macOS utun (point-to-point) interfaces only create host routes, not subnet routes.
# Without this, return traffic cannot be routed back to VPN clients.
if [ -n "\${WG_IF}" ]; then
    route add -net ${VPN_SUBNET}0/24 -interface "\${WG_IF}" 2>/dev/null || true
fi
POSTUP

# postdown.sh — unquoted heredoc so VPN_SUBNET is expanded at install time;
#                WG_IF uses \$ to expand at runtime
cat > "${WG_DIR}/postdown.sh" << POSTDOWN
#!/bin/sh
# WireGuard PostDown: Remove NAT/pass rules, subnet route, release pf reference

# 1) Get the utun interface name before cleanup
WG_IF=\$(cat /var/run/wireguard/wg0.name 2>/dev/null | tr -d '[:space:]')

# 2) Flush all rules from anchor
pfctl -a com.apple/wireguard -F all 2>/dev/null || true

# 3) Decrement pf reference count (-X)
TOKEN=\$(cat /usr/local/var/run/wireguard/pf_wireguard_token.txt 2>/dev/null)
if [ -n "\${TOKEN}" ]; then
    pfctl -X "\${TOKEN}" 2>/dev/null || true
fi

# 4) Remove subnet route
if [ -n "\${WG_IF}" ]; then
    route delete -net ${VPN_SUBNET}0/24 -interface "\${WG_IF}" 2>/dev/null || true
fi

# 5) Clean up token file
rm -f /usr/local/var/run/wireguard/pf_wireguard_token.txt
POSTDOWN

chmod 755 "${WG_DIR}/postup.sh"
chmod 755 "${WG_DIR}/postdown.sh"

# Copy management scripts to WG_DIR so users can call them from the install location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
for script in client.sh status.sh remove.sh; do
    if [[ -f "${SCRIPT_DIR}/${script}" ]]; then
        cp -f "${SCRIPT_DIR}/${script}" "${WG_DIR}/${script}"
        chmod 755 "${WG_DIR}/${script}"
    fi
done

# --- 7. Register launchd service ---
echo "[7/7] Registering auto-start on boot..."

PLIST_PATH="/Library/LaunchDaemons/com.wireguard.wg0.plist"

sudo tee "${PLIST_PATH}" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wireguard.wg0</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BREW_BASH}</string>
        <string>${WG_QUICK}</string>
        <string>up</string>
        <string>${WG_DIR}/wg0.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardErrorPath</key>
    <string>${BREW_PREFIX}/var/log/wireguard-wg0.err</string>
    <key>StandardOutPath</key>
    <string>${BREW_PREFIX}/var/log/wireguard-wg0.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

sudo chown root:wheel "${PLIST_PATH}"
sudo chmod 644 "${PLIST_PATH}"

# [FIX] enable then bootstrap (recommended by Scott Lowe)
sudo launchctl enable system/com.wireguard.wg0 2>/dev/null || true
sudo launchctl bootout system "${PLIST_PATH}" 2>/dev/null || true
sudo launchctl bootstrap system "${PLIST_PATH}"

# --- Generate wg-quick wrapper ---
# On macOS, running wg-quick with sudo uses system bash 3.2 which fails.
# This wrapper forces Homebrew bash.
WRAPPER="${BREW_PREFIX}/etc/wireguard/wg-quick-sudo.sh"
cat > "${WRAPPER}" << WRAPPER_EOF
#!/bin/zsh
# Wrapper to run wg-quick with Homebrew bash
# Usage: sudo ${WRAPPER} up|down [conf]
exec sudo "${BREW_BASH}" "${WG_QUICK}" "\$@"
WRAPPER_EOF
chmod 755 "${WRAPPER}"

# --- Done ---
echo ""
echo "============================================================"
echo "  WireGuard server setup complete!"
echo "============================================================"
echo ""
echo "  Server public key:  ${SERVER_PUBKEY}"
echo "  VPN subnet:         ${VPN_SUBNET}0/24"
echo "  Listening port:     ${SERVER_EXTERNAL_PORT}/UDP"
echo "  WAN interface:      ${WAN_INTERFACE_NAME}"
echo "  Config file:        ${WG_DIR}/wg0.conf"
echo ""
echo "  > To start now:"
echo "    sudo ${BREW_BASH} ${WG_QUICK} up ${WG_DIR}/wg0.conf"
echo ""
echo "  > To add clients:"
echo "    ${WG_DIR}/client.sh <client_name>"
echo "    (or from this directory: ./client.sh <client_name>)"
echo ""
echo "  > To stop:"
echo "    sudo ${BREW_BASH} ${WG_QUICK} down ${WG_DIR}/wg0.conf"
echo ""
echo "  WARNING: Running 'sudo wg-quick' directly will cause a"
echo "           bash 3 error. Always specify the Homebrew bash path."
echo ""
echo "  > Don't forget to set up UDP ${SERVER_EXTERNAL_PORT} port"
echo "    forwarding on your router!"
echo "============================================================"
