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
if [[ -f "$SCRIPT_DIR/helpers.sh" ]]; then
    source "$SCRIPT_DIR/helpers.sh"
else
    echo -e "${RED}❌ Helper script not found at $SCRIPT_DIR/helpers.sh${NC}"
    logger -t backhaul-watchdog "Helper script not found"
    exit 1
fi

# Check root privileges
check_root

# Load config
load_config "$CONFIG_FILE"

# Menu functions
show_menu() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ 🔧 Developed by @powermatin – Backhaul Watchdog Control Panel          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e ""
    echo -e "│ Initial setup (add endpoints)                             [1] │"
    echo -e "│ Edit configuration file                                   [2] │"
    echo -e "│ Restart watchdog service                                  [3] │"
    echo -e "│ Update watchdog script and service                        [4] │"
    echo -e "│ Remove service and config file                            [5] │"
    echo -e "│ Help (Full usage guide)                                   [6] │"
    echo -e "│ Show logs                                                [7] │"
    echo -e "│ Exit menu                                                [0] │"
    echo -e ""
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
}

add_ping_target() {
    read -rp "$(echo -e ${CYAN}"Enter new ping target (IP or domain): "${NC})" NEW_TARGET
    if ! validate_ip_or_domain "$NEW_TARGET"; then
        echo -e "${RED}❌ Invalid IP or domain format${NC}"
        logger -t backhaul-watchdog "Invalid ping target: $NEW_TARGET"
        return 1
    fi
    PING_TARGETS="$PING_TARGETS $NEW_TARGET"
    sed -i "s|^PING_TARGETS=.*|PING_TARGETS=\"$PING_TARGETS\"|" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Added $NEW_TARGET to ping targets${NC}"
    logger -t backhaul-watchdog "Added ping target: $NEW_TARGET"
}

remove_ping_target() {
    echo -e "${CYAN}Current ping targets: $PING_TARGETS${NC}"
    read -rp "$(echo -e ${CYAN}"Enter target to remove: "${NC})" TARGET
    if [[ ! " $PING_TARGETS " =~ " $TARGET " ]]; then
        echo -e "${RED}❌ Target not found${NC}"
        logger -t backhaul-watchdog "Target not found: $TARGET"
        return 1
    fi
    PING_TARGETS=$(echo "$PING_TARGETS" | sed "s/\b$TARGET\b//g" | tr -s ' ')
    sed -i "s|^PING_TARGETS=.*|PING_TARGETS=\"$PING_TARGETS\"|" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Removed $TARGET from ping targets${NC}"
    logger -t backhaul-watchdog "Removed ping target: $TARGET"
}

edit_config() {
    read -rp "$(echo -e ${CYAN}"Enter ping targets (space-separated IPs or domains) [$PING_TARGETS]: "${NC})" NEW_PING_TARGETS
    NEW_PING_TARGETS=${NEW_PING_TARGETS:-$PING_TARGETS}
    read -rp "$(echo -e ${CYAN}"Enter max latency (ms) [$MAX_LATENCY]: "${NC})" NEW_LATENCY
    NEW_LATENCY=${NEW_LATENCY:-$MAX_LATENCY}
    read -rp "$(echo -e ${CYAN}"Enter check interval (seconds) [$CHECK_INTERVAL]: "${NC})" NEW_INTERVAL
    NEW_INTERVAL=${NEW_INTERVAL:-$CHECK_INTERVAL}
    read -rp "$(echo -e ${CYAN}"Enter service name [$SERVICE_NAME]: "${NC})" NEW_SERVICE
    NEW_SERVICE=${NEW_SERVICE:-$SERVICE_NAME}
    read -rp "$(echo -e ${CYAN}"Enter cooldown (seconds) [$COOLDOWN]: "${NC})" NEW_COOLDOWN
    NEW_COOLDOWN=${NEW_COOLDOWN:-$COOLDOWN}
    read -rp "$(echo -e ${CYAN}"Enter Telegram bot token (leave empty to disable) [$TELEGRAM_BOT_TOKEN]: "${NC})" NEW_TELEGRAM_BOT_TOKEN
    NEW_TELEGRAM_BOT_TOKEN=${NEW_TELEGRAM_BOT_TOKEN:-$TELEGRAM_BOT_TOKEN}
    read -rp "$(echo -e ${CYAN}"Enter Telegram chat ID (leave empty to disable) [$TELEGRAM_CHAT_ID]: "${NC})" NEW_TELEGRAM_CHAT_ID
    NEW_TELEGRAM_CHAT_ID=${NEW_TELEGRAM_CHAT_ID:-$TELEGRAM_CHAT_ID}

    if ! validate_numeric "$NEW_LATENCY" || ! validate_numeric "$NEW_INTERVAL" || ! validate_numeric "$NEW_COOLDOWN"; then
        echo -e "${RED}❌ MAX_LATENCY, CHECK_INTERVAL, and COOLDOWN must be numeric${NC}"
        logger -t backhaul-watchdog "Invalid numeric input for configuration"
        return 1
    fi

    for TARGET in $NEW_PING_TARGETS; do
        if ! validate_ip_or_domain "$TARGET"; then
            echo -e "${RED}❌ Invalid IP or domain: $TARGET${NC}"
            logger -t backhaul-watchdog "Invalid IP or domain: $TARGET"
            return 1
        fi
    done

    sed -i "s|^PING_TARGETS=.*|PING_TARGETS=\"$NEW_PING_TARGETS\"|" "$CONFIG_FILE"
    sed -i "s|^MAX_LATENCY=.*|MAX_LATENCY=$NEW_LATENCY|" "$CONFIG_FILE"
    sed -i "s|^CHECK_INTERVAL=.*|CHECK_INTERVAL=$NEW_INTERVAL|" "$CONFIG_FILE"
    sed -i "s|^SERVICE_NAME=.*|SERVICE_NAME=\"$NEW_SERVICE\"|" "$CONFIG_FILE"
    sed -i "s|^COOLDOWN=.*|COOLDOWN=$NEW_COOLDOWN|" "$CONFIG_FILE"
    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"$NEW_TELEGRAM_BOT_TOKEN\"|" "$CONFIG_FILE"
    sed -i "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=\"$NEW_TELEGRAM_CHAT_ID\"|" "$CONFIG_FILE"

    # Update timer with new CHECK_INTERVAL
    sed -i "s/OnUnitActiveSec=.*/OnUnitActiveSec=${NEW_INTERVAL}s/" /etc/systemd/system/backhaul-watchdog.timer
    systemctl daemon-reload
    systemctl restart backhaul-watchdog.timer || {
        echo -e "${RED}❌ Failed to restart backhaul-watchdog.timer${NC}"
        logger -t backhaul-watchdog "Failed to restart backhaul-watchdog.timer"
        return 1
    }

    echo -e "${GREEN}✅ Configuration updated${NC}"
    logger -t backhaul-watchdog "Configuration updated: MAX_LATENCY=$NEW_LATENCY, CHECK_INTERVAL=$NEW_INTERVAL, SERVICE_NAME=$NEW_SERVICE, COOLDOWN=$NEW_COOLDOWN"
}

restart_service() {
    systemctl restart backhaul-watchdog.timer || {
        echo -e "${RED}❌ Failed to restart watchdog service${NC}"
        logger -t backhaul-watchdog "Failed to restart watchdog service"
        return 1
    }
    echo -e "${GREEN}✅ Watchdog service restarted${NC}"
    logger -t backhaul-watchdog "Watchdog service restarted"
}

show_help() {
    echo -e "${CYAN}=== Backhaul Watchdog Help ===${NC}"
    echo -e "This tool monitors the Backhaul tunneling service by pinging specified targets."
    echo -e "If a target is unreachable or latency exceeds MAX_LATENCY, the service is restarted."
    echo -e "\nConfiguration file: $CONFIG_FILE"
    echo -e "Logs: journalctl -t backhaul-watchdog"
    echo -e "\nMenu options:"
    echo -e "1. Initial setup: Add ping targets and configure settings."
    echo -e "2. Edit configuration: Change MAX_LATENCY, CHECK_INTERVAL, SERVICE_NAME, COOLDOWN, or Telegram settings."
    echo -e "3. Restart service: Restart the watchdog timer."
    echo -e "4. Update from GitHub: Update the watchdog to the latest version."
    echo -e "5. Remove service: Uninstall all files and services."
    echo -e "6. Help: Display this help message."
    echo -e "7. Show logs: Display recent watchdog logs."
    echo -e "0. Exit: Close the menu."
    echo -e "${CYAN}=============================${NC}"
}

show_logs() {
    echo -e "${CYAN}📜 Displaying Backhaul Watchdog logs...${NC}"
    if [[ -f /var/log/syslog ]]; then
        grep "backhaul-watchdog" /var/log/syslog | tail -n 50
    elif [[ -f /var/log/messages ]]; then
        grep "backhaul-watchdog" /var/log/messages | tail -n 50
    else
        echo -e "${RED}❌ No log file found (/var/log/syslog or /var/log/messages)${NC}"
        logger -t backhaul-watchdog "No log file found for display"
        return 1
    fi
}

# Telegram notification
send_telegram_notification() {
    local message="$1"
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" >/dev/null || {
            echo -e "${RED}❌ Failed to send Telegram notification${NC}"
            logger -t backhaul-watchdog "Failed to send Telegram notification"
            return 1
        }
    fi
}

# Watchdog logic
watchdog_loop() {
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"

    if check_cooldown "$STATE_FILE" "$COOLDOWN"; then
        echo -e "${CYAN}[Watchdog] ⏳ Skipping - last restart was recent${NC}"
        logger -t backhaul-watchdog "Skipping restart due to cooldown"
        exit 0
    fi

    if check_ssh_session; then
        echo -e "${CYAN}[Watchdog] 👤 SSH session detected, skipping restart${NC}"
        logger -t backhaul-watchdog "SSH session detected, skipping restart"
        exit 0
    fi

    for TARGET in $PING_TARGETS; do
        LATENCY=$(check_latency "$TARGET")
        if [[ "$LATENCY" == "unreachable" ]]; then
            echo -e "${RED}[Watchdog] ❌ Ping to $TARGET failed, restarting $SERVICE_NAME...${NC}"
            logger -t backhaul-watchdog "Ping to $TARGET failed, restarting $SERVICE_NAME"
            restart_service_safe "$SERVICE_NAME" "$STATE_FILE"
            send_telegram_notification "Ping to $TARGET failed, $SERVICE_NAME restarted"
            exit 0
        elif (( $(echo "$LATENCY > $MAX_LATENCY" | bc -l) )); then
            echo -e "${RED}[Watchdog] ❌ High latency ($LATENCY ms) to $TARGET, restarting $SERVICE_NAME...${NC}"
            logger -t backhaul-watchdog "High latency ($LATENCY ms) to $TARGET, restarting $SERVICE_NAME"
            restart_service_safe "$SERVICE_NAME" "$STATE_FILE"
            send_telegram_notification "High latency ($LATENCY ms) to $TARGET, $SERVICE_NAME restarted"
            exit 0
        fi
    done

    echo -e "${GREEN}[Watchdog] ✅ All targets are reachable with acceptable latency${NC}"
    logger -t backhaul-watchdog "All targets reachable with acceptable latency"
}

# Entry point
if [[ "${1:-}" == "--watchdog" ]]; then
    watchdog_loop
else
    while true; do
        show_menu
        read -rp "$(echo -e ${YELLOW}Select an option [0-7]: ${NC})" choice
        case "$choice" in
            1) add_ping_target ;;
            2) edit_config ;;
            3) restart_service ;;
            4) bash "$SCRIPT_DIR/update.sh" ;;
            5) bash "$SCRIPT_DIR/uninstall.sh" ;;
            6) show_help ;;
            7) show_logs ;;
            0) echo -e "${CYAN}👋 Exiting...${NC}"; exit 0 ;;
            *) echo -e "${RED}❌ Invalid option${NC}" ;;
        esac
        echo ""
    done
fi