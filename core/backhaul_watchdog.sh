#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "🚨 Please run this script as root."
  exit 1
fi

CONFIG_FILE="/root/backhaul_watchdog.conf"
SERVICE_FILE="/etc/systemd/system/backhaul_watchdog.service"
LOG_FILE="/var/log/backhaul_watchdog.log"
MODE="$1"

BOLD='\e[1m'; NC='\e[0m'
RED='\e[91m'; GREEN='\e[92m'; YELLOW='\e[93m'
BLUE='\e[94m'; MAGENTA='\e[95m'; CYAN='\e[96m'; GRAY='\e[90m'

validate_endpoint() {
  local ep=$1
  if [[ "$ep" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$ ]]; then
    IFS=':' read -r ip port <<< "$ep"
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        return 1
      fi
    done
    if ((port > 0 && port <= 65535)); then
      return 0
    fi
  fi
  return 1
}

print_help() {
  clear
  echo -e "${CYAN}${BOLD}Backhaul Watchdog Full Usage Guide${NC}"
  echo
  echo "This project monitors and maintains your server's tunnel connections."
  echo "If ping or connection to any specified server goes high or fails,"
  echo "the service will automatically restart the tunnel."
  echo
  echo "Main menu options:"
  echo " 1. Initial setup (add endpoints): Enter your server IP:PORT addresses here."
  echo "    Example: 192.168.1.1:443"
  echo "    If the format is wrong, you will be asked to enter again."
  echo
  echo " 2. Edit configuration file: Edit your server list manually."
  echo
  echo " 3. Restart watchdog service: Restart the monitoring service manually."
  echo
  echo " 4. Remove service and config file: Completely remove service and configs."
  echo
  echo " 0. Exit menu: Exit the control panel."
  echo
  echo "The watchdog runs automatically as a systemd service."
  echo
  echo "For questions or issues, contact the developer @powermatin."
  echo
  read -p "Press Enter to return to menu..."
}

if [ "$MODE" != "run" ]; then
  while true; do
    clear
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║ 🔧  Developed by ${YELLOW}${BOLD}@powermatin${CYAN}${BOLD} – Backhaul Watchdog Control Panel        ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}${BOLD}"
    printf "│ ${MAGENTA}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Initial setup (add endpoints)" "[1]"
    printf "│ ${CYAN}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Edit configuration file" "[2]"
    printf "│ ${BLUE}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Restart watchdog service" "[3]"
    printf "│ ${RED}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Remove service and config file" "[4]"
    printf "│ ${GRAY}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Help" "[5]"
    printf "│ ${GRAY}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Exit menu" "[0]"
    echo -e "${NC}"
    read -p "$(echo -e ${MAGENTA}${BOLD}👉 Select an option by number: ${NC})" choice

    case "$choice" in
      1)
        echo "# Backhaul endpoints config file" > "$CONFIG_FILE"
        echo "💡 How many servers do you want to add?"
        read -r COUNT
        if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || (( COUNT <= 0 )); then
          echo -e "${RED}❌ Invalid number. Returning to menu.${NC}"
          sleep 2
          continue
        fi

        for ((i=1; i<=COUNT; i++)); do
          while true; do
            read -p "🔹 Enter endpoint #$i (format IP:PORT): " line
            if validate_endpoint "$line"; then
              echo "$line" >> "$CONFIG_FILE"
              break
            else
              echo -e "${RED}⚠️ Invalid format. Please try again.${NC}"
            fi
          done
        done

        echo -e "${BLUE}🛠 Creating systemd service...${NC}"
        cat <<EOF | tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Backhaul Watchdog Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /root/backhaul_watchdog.sh run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable backhaul_watchdog.service
        systemctl start backhaul_watchdog.service
        echo -e "${GREEN}✅ Service started successfully.${NC}"
        echo "💡 It's recommended to reboot your system to apply changes."
        read -p "Press Enter to return to menu..."
        ;;
      2)
        if [ ! -f "$CONFIG_FILE" ]; then
          echo -e "${RED}⚠️ Config file not found. Please run option 1 first.${NC}"
          sleep 2
          continue
        fi
        nano "$CONFIG_FILE"
        echo "💡 It's recommended to reboot your system to apply changes."
        read -p "Press Enter to return to menu..."
        ;;
      3)
        systemctl restart backhaul_watchdog.service
        echo "$(date '+%Y-%m-%d %H:%M:%S') Watchdog service restarted manually." >> "$LOG_FILE"
        echo -e "${GREEN}✅ Watchdog service restarted.${NC}"
        read -p "Press Enter to return to menu..."
        ;;
      4)
        systemctl stop backhaul_watchdog.service
        systemctl disable backhaul_watchdog.service
        rm -f "$SERVICE_FILE" "$CONFIG_FILE"
        systemctl daemon-reload
        echo "$(date '+%Y-%m-%d %H:%M:%S') Watchdog service and config files removed." >> "$LOG_FILE"
        echo -e "${RED}🗑️ Service and config files removed.${NC}"
        read -p "Press Enter to return to menu..."
        ;;
      5)
        print_help
        ;;
      0)
        echo "👋 Goodbye!"
        exit 0
        ;;
      *)
        echo -e "${RED}❌ Invalid option.${NC}"
        sleep 1.5
        ;;
    esac
  done
  exit 0
fi


RESTART_COOLDOWN=300
LAST_RESTART=0

log() {
  local msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

check_tls() {
  echo | timeout 5 openssl s_client -connect "$1:$2" -servername "$1" -verify_return_error 2>/dev/null | grep -q "Verify return code: 0"
}

check_tcp() {
  nc -z -w 3 "$1" "$2" >/dev/null 2>&1
}

check_ping() {
  ping -c 2 -W 2 "$1" >/dev/null 2>&1
}

check_curl() {
  local PROTO="http"
  [[ "$2" == "443" || "$2" == "2053" ]] && PROTO="https"
  curl -s --connect-timeout 3 "$PROTO://$1:$2" >/dev/null
}

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}❌ Config file not found. Please add endpoints first.${NC}"
  exit 1
fi

ENDPOINTS_COUNT=$(grep -v '^#' "$CONFIG_FILE" | grep -c '.')
if (( ENDPOINTS_COUNT == 0 )); then
  echo -e "${RED}❌ No endpoints found. Please add endpoints first.${NC}"
  exit 1
fi

while true; do
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    if ! [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
      log "⚠️ Invalid line skipped in config: $line"
      continue
    fi

    IP="${line%%:*}"
    PORT="${line##*:}"
    TIME_NOW=$(date '+%Y-%m-%d %H:%M:%S')

    FAIL=0
    check_tls "$IP" "$PORT" || { log "❌ TLS failed for $IP:$PORT"; FAIL=1; }
    check_tcp "$IP" "$PORT" || { log "❌ TCP failed for $IP:$PORT"; FAIL=1; }
    check_ping "$IP" || { log "❌ Ping failed for $IP"; FAIL=1; }
    check_curl "$IP" "$PORT" || { log "❌ Curl failed for $IP:$PORT"; FAIL=1; }

    if (( FAIL )); then
      CURRENT_TIME=$(date +%s)
      if (( CURRENT_TIME - LAST_RESTART >= RESTART_COOLDOWN )); then
        if systemctl is-active --quiet backhaul.service; then
          log "🔁 Restarting backhaul via systemctl"
          systemctl restart backhaul.service
          log "✔️ backhaul restarted successfully"
        else
          log "⚠️ backhaul service not active, skipping restart"
        fi
        LAST_RESTART=$CURRENT_TIME
      fi
    fi
  done < <(grep -v '^#' "$CONFIG_FILE")
  sleep 20
done
