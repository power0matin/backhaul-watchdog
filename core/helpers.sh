#!/bin/bash
set -euo pipefail

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[0;31m❌ This script must be run as root\033[0m"
        exit 1
    fi
}

# Load configuration
load_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        echo -e "\033[0;31m❌ Config file not found at $config_file\033[0m"
        exit 1
    fi
    source "$config_file"
    if [[ -z "$PING_TARGETS" || -z "$MAX_LATENCY" || -z "$CHECK_INTERVAL" || -z "$SERVICE_NAME" || -z "$COOLDOWN" ]]; then
        echo -e "\033[0;31m❌ Invalid or missing configuration in $config_file\033[0m"
        exit 1
    fi
}

# Validate numeric input
validate_numeric() {
    local input="$1"
    [[ "$input" =~ ^[0-9]+$ ]]
}

# Validate IP or domain
validate_ip_or_domain() {
    local input="$1"
    [[ "$input" =~ ^[0-9.]+$ ]] || [[ "$input" =~ ^[a-zA-Z0-9.-]+$ ]]
}

# Check latency
check_latency() {
    local target="$1"
    local result
    result=$(ping -c 1 -W 2 "$target" 2>/dev/null | grep -o "time=[0-9.]*" | cut -d'=' -f2 || echo "unreachable")
    echo "$result"
}

# Check cooldown
check_cooldown() {
    local state_file="$1"
    local cooldown="$2"
    if [[ -f "$state_file" ]]; then
        local last_action_time
        local now
        local elapsed
        last_action_time=$(cat "$state_file")
        now=$(date +%s)
        elapsed=$((now - last_action_time))
        if [[ "$elapsed" -lt "$cooldown" ]]; then
            return 0
        fi
    fi
    return 1
}

# Check for active SSH session
check_ssh_session() {
    who | grep -qE "ssh"
}

# Restart service safely
restart_service_safe() {
    local service="$1"
    local state_file="$2"
    systemctl restart "$service" || {
        echo -e "\033[0;31m❌ Failed to restart $service\033[0m"
        exit 1
    }
    date +%s > "$state_file"
    chmod 600 "$state_file"
}