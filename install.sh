#!/bin/bash

set -e

BIN_PATH="/usr/local/bin/backhaul-watchdog"
CLI_ALIAS="/usr/local/bin/watchdog"
SERVICE_PATH="/etc/systemd/system/backhaul_watchdog.service"
CONFIG_PATH="/root/backhaul_watchdog.conf"
REPO_URL="https://raw.githubusercontent.com/power0matin/backhaul-watchdog/master"

echo "🚀 Installing Backhaul Watchdog..."

# Download main script
curl -Ls "$REPO_URL/core/backhaul_watchdog.sh" -o "$BIN_PATH"
chmod +x "$BIN_PATH"

# Create CLI alias
echo -e "#!/bin/bash\nbash $BIN_PATH \"\$@\"" > "$CLI_ALIAS"
chmod +x "$CLI_ALIAS"

# Download sample config if not exists
if [ ! -f "$CONFIG_PATH" ]; then
  curl -Ls "$REPO_URL/core/config_example.conf" -o "$CONFIG_PATH"
fi

# Download systemd service
curl -Ls "$REPO_URL/core/systemd_example.service" -o "$SERVICE_PATH"
systemctl daemon-reload
systemctl enable backhaul_watchdog
systemctl start backhaul_watchdog

echo "✅ Installed successfully!"
echo "👉 You can now run it using: ${YELLOW}watchdog${NC}"
