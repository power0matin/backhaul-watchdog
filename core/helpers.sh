#!/bin/bash
set -euo pipefail

# Validate IP or domain
validate_ip_or_domain() {
    local target="$1"
    if [[ "$target" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    elif [[ "$target" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# Validate numeric input
validate_numeric() {
    local input="$1"
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[0;31m❌ This script must be run as root\033[0m"
        logger -t backhaul-watchdog "Operation failed: root privileges required"
        exit 1
    fi
}

# Load configuration
load_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        echo -e "\033[0;31m❌ Configuration file $config_file not found\033[0m"
        logger -t backhaul-watchdog "Configuration file $config_file not found"
        exit 1
    fi
    source "$config_file"
}

# Check latency
check_latency() {
    local target="$1"
    local ping_output
    ping_output=$(ping -c 1 -W 2 "$target" 2>/dev/null | grep 'time=')
    if [[ -z "$ping_output" ]]; then
        echo "unreachable"
    else
        echo "$ping_output" | grep -o 'time=[0-9.]*' | cut -d'=' -f2
    fi
}

# Check cooldown
check_cooldown() {
    local state_file="$1"
    local cooldown="$2"
    if [[ -f "$state_file" ]]; then
        local last_action
        last_action=$(cat "$state_file")
        local current_time
        current_time=$(date +%s)
        local time_diff=$((current_time - last_action))
        if [[ $time_diff -lt $cooldown ]]; then
            return 0
        fi
    fi
    return 1
}

# Safe service restart
restart_service_safe() {
    local service_name="$1"
    local state_file="$2"
    systemctl restart "$service_name" || {
        echo -e "\033[0;31m❌ Failed to restart $service_name\033[0m"
        logger -t backhaul-watchdog "Failed to restart $service_name"
        return 1
    }
    date +%s > "$state_file"
    echo -e "\033[0;32m✅ Restarted $service_name\033[0m"
    logger -t backhaul-watchdog "Restarted $service_name"
}

# Check for active SSH sessions
check_ssh_session() {
    if who | grep -q 'pts/'; then
        return 0
    fi
    return 1
}