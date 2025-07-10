#!/bin/bash
set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths
CONFIG_DIR="/etc/backhaul_watchdog"
CONFIG_FILE="$CONFIG_DIR/backhaul_watchdog.conf"
STATE_DIR="/var/lib/backhaul_watchdog"
STATE_FILE="$STATE_DIR/last_action"
SCRIPT_DIR="/usr/local/bin/backhaul_watchdog"

# Load helpers
source "$SCRIPT_DIR/helpers.sh"

# Check root privileges
check_root

# Load config
load_config "$CONFIG_FILE"

# Menu functions
show_menu() {
    echo -e "${CYAN}=== Backhaul Watchdog Menu ===${NC}"
    echo -e "1. Add ping target"
    echo -e "2. Remove ping target"
    echo -e "3. Edit configuration"
    echo -e "4. Restart watchdog service"
    echo -e "5. Update from GitHub"
    echo -e "6. Uninstall watchdog"
    echo -e "7. Show help"
    echo -e "8. Exit"
    echo -e "${CYAN}=============================${NC}"
}

add_ping_target() {
    read -rp "$(echo -e ${CYAN}"Enter new ping target (IP or domain): "${NC})" NEW_TARGET
    if ! validate_ip_or_domain "$NEW_TARGET"; then
        echo -e "${RED}❌ Invalid IP or domain format${NC}"
        return 1
    fi
    PING_TARGETS="$PING_TARGETS $NEW_TARGET"
    sed -i "s|^PING_TARGETS=.*|PING_TARGETS=\"$PING_TARGETS\"|" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Added $NEW_TARGET to ping targets${NC}"
}

remove_ping_target() {
    echo -e "${CYAN}Current ping targets: $PING_TARGETS${NC}"
    read -rp "$(echo -e ${CYAN}"Enter target to remove: "${NC})" TARGET
    if [[ ! " $PING_TARGETS " =~ " $TARGET " ]]; then
        echo -e "${RED}❌ Target not found${NC}"
        return 1
    fi
    PING_TARGETS=$(echo "$PING_TARGETS" | sed "s/\b$TARGET\b//g" | tr -s ' ')
    sed -i "s|^PING_TARGETS=.*|PING_TARGETS=\"$PING_TARGETS\"|" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Removed $TARGET from ping targets${NC}"
}

edit_config() {
    read -rp "$(echo -e ${CYAN}"Enter max latency (ms) [$MAX_LATENCY]: "${NC})" NEW_LATENCY
    NEW_LATENCY=${NEW_LATENCY:-$MAX_LATENCY}
    read -rp "$(echo -e ${CYAN}"Enter check interval (seconds) [$CHECK_INTERVAL]: "${NC})" NEW_INTERVAL
    NEW_INTERVAL=${NEW_INTERVAL:-$CHECK_INTERVAL}
    read -rp "$(echo -e ${CYAN}"Enter service name [$SERVICE_NAME]: "${NC})" NEW_SERVICE
    NEW_SERVICE=${NEW_SERVICE:-$SERVICE_NAME}
    read -rp "$(echo -e ${CYAN}"Enter cooldown (seconds) [$COOLDOWN]: "${NC})" NEW_COOLDOWN
    NEW_COOLDOWN=${NEW_COOLDOWN:-$COOLDOWN}

    if ! validate_numeric "$NEW_LATENCY" || ! validate_numeric "$NEW_INTERVAL" || ! validate_numeric "$NEW_COOLDOWN"; then
        echo -e "${RED}❌ MAX_LATENCY, CHECK_INTERVAL, and COOLDOWN must be numeric${NC}"
        return 1
    fi

    sed -i "s|^MAX_LATENCY=.*|MAX_LATENCY=$NEW_LATENCY|" "$CONFIG_FILE"
    sed -i "s|^CHECK_INTERVAL=.*|CHECK_INTERVAL=$NEW_INTERVAL|" "$CONFIG_FILE"
    sed -i "s|^SERVICE_NAME=.*|SERVICE_NAME=\"$NEW_SERVICE\"|" "$CONFIG_FILE"
    sed -i "s|^COOLDOWN=.*|COOLDOWN=$NEW_COOLDOWN|" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Configuration updated${NC}"
}

restart_service() {
    systemctl restart backhaul-watchdog.timer || {
        echo -e "${RED}❌ Failed to restart watchdog service${NC}"
        return 1
    }
    echo -e "${GREEN}✅ Watchdog service restarted${NC}"
}

show_help() {
    echo -e "${CYAN}=== Backhaul Watchdog Help ===${NC}"
    echo -e "This tool monitors the Backhaul tunneling service by pinging specified targets."
    echo -e "If a target is unreachable or latency exceeds MAX_LATENCY, the service is restarted."
    echo -e "\nConfiguration file: $CONFIG_FILE"
    echo -e "Logs: journalctl -u backhaul-watchdog"
    echo -e "\nMenu options:"
    echo -e "1. Add ping target: Add a new IP or domain to ping."
    echo -e "2. Remove ping target: Remove an existing ping target."
    echo -e "3. Edit configuration: Change MAX_LATENCY, CHECK_INTERVAL, SERVICE_NAME, or COOLDOWN."
    echo -e "4. Restart watchdog: Restart the watchdog service."
    echo -e "5. Update from GitHub: Update the watchdog to the latest version."
    echo -e "6. Uninstall watchdog: Remove all files and services."
    echo -e "7. Show help: Display this help message."
    echo -e "8. Exit: Close the menu."
    echo -e "${CYAN}=============================${NC}"
}

# Watchdog logic
watchdog_loop() {
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"

    if check_cooldown "$STATE_FILE" "$COOLDOWN"; then
        echo -e "${CYAN}[Watchdog] ⏳ Skipping - last restart was recent${NC}"
        exit 0
    fi

    if check_ssh_session; then
        echo -e "${CYAN}[Watchdog] 👤 SSH session detected, skipping restart${NC}"
        exit 0
    fi

    for TARGET in $PING_TARGETS; do
        LATENCY=$(check_latency "$TARGET")
        if [[ "$LATENCY" == "unreachable" ]]; then
            echo -e "${RED}[Watchdog] ❌ Ping to $TARGET failed, restarting $SERVICE_NAME...${NC}"
            restart_service_safe "$SERVICE_NAME" "$STATE_FILE"
            exit 0
        elif (( $(echo "$LATENCY > $MAX_LATENCY" | bc -l) )); then
            echo -e "${RED}[Watchdog] ❌ High latency ($LATENCY ms) to $TARGET, restarting $SERVICE_NAME...${NC}"
            restart_service_safe "$SERVICE_NAME" "$STATE_FILE"
            exit 0
        fi
    done

    echo -e "${GREEN}[Watchdog] ✅ All targets are reachable with acceptable latency${NC}"
}

# Main logic
if [[ "${1:-}" == "--watchdog" ]]; then
    watchdog_loop
else
    while true; do
        show_menu
        read -rp "$(echo -e ${CYAN}"Select an option [1-8]: "${NC})" OPTION
        case $OPTION in
            1) add_ping_target ;;
            2) remove_ping_target ;;
            3) edit_config ;;
            4) restart_service ;;
            5) bash "$SCRIPT_DIR/update.sh" ;;
            6) bash "$SCRIPT_DIR/uninstall.sh" && exit 0 ;;
            7) show_help ;;
            8) echo -e "${GREEN}👋 Exiting...${NC}" && exit 0 ;;
            *) echo -e "${RED}❌ Invalid option${NC}" ;;
        esac
        read -rp "$(echo -e ${YELLOW}"Press Enter to continue...${NC})"
    done
fi