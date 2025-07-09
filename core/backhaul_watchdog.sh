#!/bin/bash

SERVICE_NAME="backhaul_watchdog.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
CONFIG_FILE="/root/backhaul_watchdog.conf"
WATCHDOG_SCRIPT="/root/backhaul_watchdog.sh"
GITHUB_REPO="https://raw.githubusercontent.com/power0matin/backhaul-watchdog/main"

print_help() {
  clear
  cat <<EOF
Backhaul Watchdog Full Usage Guide

1. Initial setup (add endpoints):
   Enter your servers in IP:PORT format, e.g., 192.168.1.1:443.
   Invalid inputs won't be saved and you'll be asked to re-enter.

2. Edit configuration file:
   Opens the config file for manual editing.

3. Restart watchdog service:
   Restarts the monitoring systemd service.

4. Update:
   Downloads the latest watchdog script and service file from GitHub,
   replaces old files, and restarts the service.

5. Remove:
   Stops and disables the service,
   deletes config and service files completely.

6. Help:
   Show this help message.

0. Exit:
   Exit the control panel.

EOF
  read -p "Press Enter to return to menu..."
}

validate_endpoint() {
  local ep=$1
  if [[ "$ep" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$ ]]; then
    IFS=':' read -r ip port <<< "$ep"
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then return 1; fi
    done
    if ((port > 0 && port <= 65535)); then
      return 0
    fi
  fi
  return 1
}

initial_setup() {
  echo "# Backhaul endpoints config file" > "$CONFIG_FILE"
  read -p "How many servers do you want to add? " count
  if ! [[ "$count" =~ ^[0-9]+$ ]] || ((count <= 0)); then
    echo "Invalid number. Returning to menu."
    sleep 2
    return
  fi

  for ((i=1; i<=count; i++)); do
    while true; do
      read -p "Enter endpoint #$i (IP:PORT): " line
      if validate_endpoint "$line"; then
        echo "$line" >> "$CONFIG_FILE"
        break
      else
        echo "Invalid format, try again."
      fi
    done
  done

  echo "Creating systemd service..."
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Backhaul Watchdog Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $WATCHDOG_SCRIPT run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
  echo "Service started successfully. Please reboot to ensure full operation."
  read -p "Press Enter to return to menu..."
}

edit_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found. Run initial setup first."
    sleep 2
    return
  fi
  nano "$CONFIG_FILE"
}

restart_service() {
  systemctl restart "$SERVICE_NAME"
  echo "Watchdog service restarted."
  read -p "Press Enter to return to menu..."
}

update_watchdog() {
  echo "Updating watchdog script and service..."
  curl -fsSL "$GITHUB_REPO/backhaul_watchdog.sh" -o "$WATCHDOG_SCRIPT" || { echo "Failed to download script"; sleep 2; return; }
  curl -fsSL "$GITHUB_REPO/backhaul_watchdog.service" -o "$SERVICE_FILE" || { echo "Failed to download service file"; sleep 2; return; }

  chmod +x "$WATCHDOG_SCRIPT"
  systemctl daemon-reload
  systemctl restart "$SERVICE_NAME"
  echo "Update complete and service restarted."
  read -p "Press Enter to return to menu..."
}

remove_watchdog() {
  echo "Removing watchdog service and config files..."
  systemctl stop "$SERVICE_NAME"
  systemctl disable "$SERVICE_NAME"
  rm -f "$SERVICE_FILE" "$CONFIG_FILE" "$WATCHDOG_SCRIPT"
  systemctl daemon-reload
  echo "Removed all related files and service."
  read -p "Press Enter to return to menu..."
}

while true; do
  clear
  cat <<EOF
╔════════════════════════════════════════════════════════════════════════╗
║ 🔧  Developed by @powermatin – Backhaul Watchdog Control Panel        ║
╚════════════════════════════════════════════════════════════════════════╝

│ Initial setup (add endpoints)                             [1] │
│ Edit configuration file                                   [2] │
│ Restart watchdog service                                  [3] │
│ Update watchdog script and service                        [4] │
│ Remove service and config file                            [5] │
│ Help (Full usage guide)                                   [6] │
│ Exit menu                                                [0] │

╚════════════════════════════════════════════════════════════════════════╝
EOF
  read -p "👉 Select an option by number: " choice

  case "$choice" in
    1) initial_setup ;;
    2) edit_config ;;
    3) restart_service ;;
    4) update_watchdog ;;
    5) remove_watchdog ;;
    6) print_help ;;
    0) echo "Goodbye!"; exit 0 ;;
    *) echo "Invalid option"; sleep 1.5 ;;
  esac
done
