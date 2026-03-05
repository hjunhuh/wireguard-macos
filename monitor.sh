#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2162,SC2051

# ============================================================
# WireGuard Real-Time Monitor Dashboard
# Usage: sudo ./monitor.sh
# ============================================================

# --- Detect architecture ---
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

WG_DIR="${BREW_PREFIX}/etc/wireguard"
WG_BIN="${BREW_PREFIX}/bin/wg"

# --- Constants ---
REFRESH_INTERVAL=2
HANDSHAKE_TIMEOUT=180
MAP_REFRESH_INTERVAL=15  # re-scan client dirs every 15 iterations (30s)

# --- ANSI colors ---
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_GREEN='\033[32m'
C_RED='\033[31m'
# shellcheck disable=SC2034
C_CYAN='\033[36m'
C_BOLD_GREEN='\033[1;32m'
C_BOLD_RED='\033[1;31m'
C_BOLD_CYAN='\033[1;36m'

# --- Root check ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo "[!] This script requires root privileges."
    echo "    Usage: sudo ./monitor.sh"
    exit 1
fi

# --- Associative arrays ---
typeset -A PEER_NAME PEER_IP
typeset -A PREV_RX PREV_TX PREV_TIME RATE_RX RATE_TX

# --- Build pubkey -> client name/IP map ---
build_pubkey_map() {
    PEER_NAME=()
    PEER_IP=()
    if [[ -d "${WG_DIR}/clients" ]]; then
        for client_dir in "${WG_DIR}/clients"/*/; do
            [[ -d "${client_dir}" ]] || continue
            local name
            name=$(basename "${client_dir}")
            local pubkey
            pubkey=$(tr -d '[:space:]' < "${client_dir}/publickey" 2>/dev/null)
            local ip
            ip=$(tr -d '[:space:]' < "${client_dir}/ip" 2>/dev/null)
            if [[ -n "${pubkey}" ]]; then
                PEER_NAME[${pubkey}]="${name}"
                # shellcheck disable=SC2034
                PEER_IP[${pubkey}]="${ip}"
            fi
        done
    fi
}

# --- Format bytes to human-readable ---
format_bytes() {
    local bytes=${1:-0}
    if [[ ${bytes} -lt 1024 ]]; then
        printf "%d B" "${bytes}"
    elif [[ ${bytes} -lt 1048576 ]]; then
        awk "BEGIN {printf \"%.1f KB\", ${bytes}/1024}"
    elif [[ ${bytes} -lt 1073741824 ]]; then
        awk "BEGIN {printf \"%.1f MB\", ${bytes}/1048576}"
    elif [[ ${bytes} -lt 1099511627776 ]]; then
        awk "BEGIN {printf \"%.2f GB\", ${bytes}/1073741824}"
    else
        awk "BEGIN {printf \"%.2f TB\", ${bytes}/1099511627776}"
    fi
}

# --- Format bytes/sec to human-readable rate ---
format_rate() {
    local bps=${1:-0}
    if [[ ${bps} -lt 1024 ]]; then
        printf "%d B/s" "${bps}"
    elif [[ ${bps} -lt 1048576 ]]; then
        awk "BEGIN {printf \"%.1f KB/s\", ${bps}/1024}"
    else
        awk "BEGIN {printf \"%.1f MB/s\", ${bps}/1048576}"
    fi
}

# --- Format timestamp to relative time ---
format_relative_time() {
    local timestamp=${1:-0}
    if [[ ${timestamp} -eq 0 ]]; then
        printf "never"
        return
    fi
    local now
    now=$(date +%s)
    local delta=$((now - timestamp))
    if [[ ${delta} -lt 0 ]]; then
        printf "just now"
    elif [[ ${delta} -lt 60 ]]; then
        printf "%ds ago" "${delta}"
    elif [[ ${delta} -lt 3600 ]]; then
        printf "%dm %ds ago" "$((delta / 60))" "$((delta % 60))"
    elif [[ ${delta} -lt 86400 ]]; then
        printf "%dh %dm ago" "$((delta / 3600))" "$((delta % 3600 / 60))"
    else
        printf "%dd %dh ago" "$((delta / 86400))" "$((delta % 86400 / 3600))"
    fi
}

# --- Format uptime ---
format_uptime() {
    local start=$1
    local now
    now=$(date +%s)
    local delta=$((now - start))
    if [[ ${delta} -lt 60 ]]; then
        printf "%ds" "${delta}"
    elif [[ ${delta} -lt 3600 ]]; then
        printf "%dm %ds" "$((delta / 60))" "$((delta % 60))"
    elif [[ ${delta} -lt 86400 ]]; then
        printf "%dh %dm" "$((delta / 3600))" "$((delta % 3600 / 60))"
    else
        printf "%dd %dh %dm" "$((delta / 86400))" "$((delta % 86400 / 3600))" "$((delta % 3600 / 60))"
    fi
}

# --- Cleanup on exit ---
cleanup() {
    printf '\033[?25h'  # show cursor
    printf '\033[0m'    # reset colors
    echo ""
    echo "[*] Monitor stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM

# --- Check server running ---
WG_REAL_IF=$(tr -d '[:space:]' < /var/run/wireguard/wg0.name 2>/dev/null)
if [[ -z "${WG_REAL_IF}" ]]; then
    echo "[!] WireGuard is not running."
    echo "    Start with: sudo ${BREW_PREFIX}/bin/bash ${BREW_PREFIX}/bin/wg-quick up ${WG_DIR}/wg0.conf"
    exit 1
fi

# --- Server start time ---
WG_START=$(stat -f %m /var/run/wireguard/wg0.name 2>/dev/null || echo "0")

# --- Build initial pubkey map ---
build_pubkey_map

# --- Hide cursor ---
printf '\033[?25l'

# --- Main render tick (wrapped in function so `local` is valid) ---
render_tick() {
    # Collect data (single wg show dump call)
    local dump_output
    dump_output=$("${WG_BIN}" show "${WG_REAL_IF}" dump 2>/dev/null)
    if [[ -z "${dump_output}" ]]; then
        return 1
    fi

    # Parse interface line
    local iface_line
    iface_line=$(echo "${dump_output}" | head -1)
    local SERVER_PUBKEY
    SERVER_PUBKEY=$(echo "${iface_line}" | awk -F'\t' '{print $2}')
    local SERVER_PORT
    SERVER_PORT=$(echo "${iface_line}" | awk -F'\t' '{print $3}')

    # Parse peer lines into arrays
    typeset -a D_PK D_EP D_HS D_RX D_TX
    D_PK=()
    D_EP=()
    D_HS=()
    D_RX=()
    D_TX=()

    # shellcheck disable=SC2034
    while IFS=$'\t' read -r pubkey psk endpoint allowed handshake rx tx keepalive; do
        D_PK+=("${pubkey}")
        D_EP+=("${endpoint}")
        D_HS+=("${handshake}")
        D_RX+=("${rx}")
        D_TX+=("${tx}")
    done < <(echo "${dump_output}" | tail -n +2)

    # Calculate bandwidth
    local now_ts
    now_ts=$(date +%s)
    for i in {1..${#D_PK[@]}}; do
        local pk="${D_PK[$i]}"
        local cur_rx="${D_RX[$i]}"
        local cur_tx="${D_TX[$i]}"

        if [[ -n "${PREV_RX[${pk}]}" ]]; then
            local dt=$((now_ts - PREV_TIME[${pk}]))
            if [[ ${dt} -gt 0 ]]; then
                RATE_RX[${pk}]=$(( (cur_rx - PREV_RX[${pk}]) / dt ))
                RATE_TX[${pk}]=$(( (cur_tx - PREV_TX[${pk}]) / dt ))
            fi
        else
            RATE_RX[${pk}]=0
            RATE_TX[${pk}]=0
        fi

        PREV_RX[${pk}]="${cur_rx}"
        PREV_TX[${pk}]="${cur_tx}"
        PREV_TIME[${pk}]="${now_ts}"
    done

    # Aggregate totals
    local TOTAL_RX=0 TOTAL_TX=0 TOTAL_RATE_RX=0 TOTAL_RATE_TX=0
    local ONLINE_COUNT=0 TOTAL_PEERS=${#D_PK[@]}

    for i in {1..${#D_PK[@]}}; do
        local pk="${D_PK[$i]}"
        TOTAL_RX=$((TOTAL_RX + ${D_RX[$i]}))
        TOTAL_TX=$((TOTAL_TX + ${D_TX[$i]}))
        TOTAL_RATE_RX=$((TOTAL_RATE_RX + ${RATE_RX[${pk}]:-0}))
        TOTAL_RATE_TX=$((TOTAL_RATE_TX + ${RATE_TX[${pk}]:-0}))

        local hs=${D_HS[$i]}
        if [[ ${hs} -ne 0 ]] && [[ $((now_ts - hs)) -le ${HANDSHAKE_TIMEOUT} ]]; then
            ONLINE_COUNT=$((ONLINE_COUNT + 1))
        fi
    done

    # --- Render dashboard ---
    local now_str
    now_str=$(date "+%Y-%m-%d %H:%M:%S")
    local short_key="${SERVER_PUBKEY:0:20}..."
    local uptime_str
    uptime_str=$(format_uptime "${WG_START}")
    local output=""

    # Move cursor home
    output+='\033[H'

    # Header
    output+="${C_BOLD}============================================================${C_RESET}\n"
    output+="$(printf "  ${C_BOLD}WireGuard Monitor${C_RESET}                     ${C_DIM}[%s]${C_RESET}" "${now_str}")\n"
    output+="${C_BOLD}============================================================${C_RESET}\n"
    output+="\n"

    # Server info
    output+="$(printf "  Interface:  ${C_BOLD_CYAN}%-16s${C_RESET}  Port: ${C_BOLD}%s${C_RESET}" "${WG_REAL_IF}" "${SERVER_PORT}")\n"
    output+="$(printf "  Public Key: %s" "${short_key}")\n"
    output+="$(printf "  Uptime:     %-20s  Peers: ${C_BOLD}%d/%d${C_RESET} online" "${uptime_str}" "${ONLINE_COUNT}" "${TOTAL_PEERS}")\n"
    output+="\n"

    # Column header
    output+="${C_DIM}------------------------------------------------------------${C_RESET}\n"
    output+="$(printf "  ${C_BOLD}%-14s%-10s%-20s%s${C_RESET}" "CLIENT" "STATUS" "ENDPOINT" "LAST HANDSHAKE")\n"
    output+="${C_DIM}------------------------------------------------------------${C_RESET}\n"

    # Per-peer rows
    if [[ ${TOTAL_PEERS} -eq 0 ]]; then
        output+="  ${C_DIM}(no peers configured)${C_RESET}\n"
    else
        for i in {1..${#D_PK[@]}}; do
            local pk="${D_PK[$i]}"
            local name="${PEER_NAME[${pk}]:-${pk:0:12}...}"
            local hs=${D_HS[$i]}
            local endpoint="${D_EP[$i]}"
            [[ "${endpoint}" == "(none)" ]] && endpoint="--"

            local status_str status_color
            if [[ ${hs} -eq 0 ]] || [[ $((now_ts - hs)) -gt ${HANDSHAKE_TIMEOUT} ]]; then
                status_str="OFFLINE"
                status_color="${C_BOLD_RED}"
            else
                status_str="ONLINE"
                status_color="${C_BOLD_GREEN}"
            fi

            local hs_str
            hs_str=$(format_relative_time "${hs}")
            local rx_str
            rx_str=$(format_bytes "${D_RX[$i]}")
            local tx_str
            tx_str=$(format_bytes "${D_TX[$i]}")
            local rx_rate
            rx_rate=$(format_rate "${RATE_RX[${pk}]:-0}")
            local tx_rate
            tx_rate=$(format_rate "${RATE_TX[${pk}]:-0}")

            output+="$(printf "  ${C_BOLD}%-14s${C_RESET}${status_color}%-10s${C_RESET}%-20s%s" "${name}" "${status_str}" "${endpoint}" "${hs_str}")\n"
            output+="$(printf "                RX: %-12s (%-10s) TX: %-12s (%s)" "${rx_str}" "${rx_rate}" "${tx_str}" "${tx_rate}")\n"
        done
    fi

    # Footer
    output+="${C_DIM}------------------------------------------------------------${C_RESET}\n"
    output+="\n"

    local total_rx_str
    total_rx_str=$(format_bytes "${TOTAL_RX}")
    local total_tx_str
    total_tx_str=$(format_bytes "${TOTAL_TX}")
    local total_rx_rate
    total_rx_rate=$(format_rate "${TOTAL_RATE_RX}")
    local total_tx_rate
    total_tx_rate=$(format_rate "${TOTAL_RATE_TX}")
    local offline_count=$((TOTAL_PEERS - ONLINE_COUNT))

    output+="$(printf "  ${C_BOLD}TOTALS${C_RESET}        RX: %-12s (%-10s) TX: %-12s (%s)" "${total_rx_str}" "${total_rx_rate}" "${total_tx_str}" "${total_tx_rate}")\n"
    output+="$(printf "  ${C_BOLD}PEERS${C_RESET}         %d registered, ${C_GREEN}%d online${C_RESET}, ${C_RED}%d offline${C_RESET}" "${TOTAL_PEERS}" "${ONLINE_COUNT}" "${offline_count}")\n"
    output+="\n"
    output+="${C_BOLD}============================================================${C_RESET}\n"
    output+="$(printf "  Refresh: %ds | Ctrl+C to exit" "${REFRESH_INTERVAL}")\n"
    output+="${C_BOLD}============================================================${C_RESET}\n"

    # Clear remaining lines from previous frame
    output+='\033[J'

    printf '%b' "${output}"
}

# --- Main loop ---
ITERATION=0
while true; do
    ITERATION=$((ITERATION + 1))

    # Refresh pubkey map periodically
    if (( ITERATION % MAP_REFRESH_INTERVAL == 0 )); then
        build_pubkey_map
    fi

    # Check server still running
    WG_REAL_IF=$(tr -d '[:space:]' < /var/run/wireguard/wg0.name 2>/dev/null)
    if [[ -z "${WG_REAL_IF}" ]]; then
        printf '\033[H\033[2J'
        echo ""
        echo "  [!] WireGuard server has stopped."
        echo "      Waiting for restart... (Ctrl+C to exit)"
        sleep ${REFRESH_INTERVAL}
        continue
    fi

    render_tick || { sleep ${REFRESH_INTERVAL}; continue; }

    sleep ${REFRESH_INTERVAL}
done
