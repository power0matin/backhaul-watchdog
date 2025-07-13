#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[1;36m'
RED='\033[0;31m'
NC='\033[0m'

# Root check
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root.${NC}"
    logger -t backhaul-watchdog "Installation failed: root privileges required"
    exit 1
fi

echo -e "${CYAN}🔧 Starting Backhaul Watchdog installation...${NC}"

# Paths
BASE_DIR="/usr/local/bin/backhaul_watchdog"
CONFIG_DIR="/etc/backhaul_watchdog"
SYSTEMD_DIR="/etc/systemd/system"
TEST_DIR="/usr/local/bin/backhaul_watchdog/tests"
REPO_URL="https://github.com/power0matin/backhaul-watchdog"

# Dependency check
for cmd in git curl bc; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ Required dependency '$cmd' is not installed.${NC}"
        logger -t backhaul-watchdog "Missing dependency: $cmd"
        exit 1
    fi
done

# Clean previous install
rm -rf "$BASE_DIR" "$CONFIG_DIR" "$TEST_DIR"
mkdir -p "$BASE_DIR" "$CONFIG_DIR" "$TEST_DIR" "$SYSTEMD_DIR"

# Download helper
download() {
    local remote_path="$1"
    local local_path="$2"
    echo -e "${CYAN}⬇️  Downloading $remote_path...${NC}"
    curl -Ls "$REPO_URL/raw/main/$remote_path" -o "$local_path" || {
        echo -e "${RED}❌ Failed to download $remote_path${NC}"
        logger -t backhaul-watchdog "Failed to download $remote_path"
        exit 1
    }
    if [[ ! -s "$local_path" ]]; then
        echo -e "${RED}❌ File $remote_path is empty or invalid${NC}"
        logger -t backhaul-watchdog "File $remote_path is empty or invalid"
        exit 1
    
}

echo -e "${GREEN}📥 Downloading files from GitHub...${NC}"

# Core scripts
for file in backhaul_watchdog.sh helpers.sh update.sh uninstall.sh setup_endpoints.sh; do
    download "core/$file" "$BASE_DIR/$file"
done

# Config files
download "config/config_example.conf" "$CONFIG_DIR/backhaul_watchdog.conf"

# Systemd service files
for file in backhaul-watchdog.service backhaul-watchdog.timer; do
    download "systemd/$file" "$SYSTEMD_DIR/$file"
done

# Test scripts
for file in test_helpers.bats test_service.bats; do
    download "tests/$file" "$TEST_DIR/$file"
done

# Set permissions
chmod +x "$BASE_DIR/"*.sh
chmod 600 "$CONFIG_DIR/backhaul_watchdog.conf"

# Unmask service and timer if masked
for unit in backhaul-watchdog.service backhaul-watchdog.timer; do
    if systemctl is-enabled "$unit" 2>/dev/null | grep -q "masked"; then
        echo -e "${GREEN}🔧 Unmasking $unit...${NC}"
        systemctl unmask "$unit" || {
            echo -e "${RED}❌ Failed to unmask $unit${NC}"
            logger -t backhaul-watchdog "Failed to unmask $unit"
            exit 1
        }
    fi
done

# Enable and start systemd timer
echo -e "${GREEN}🔄 Enabling systemd services...${NC}"
systemctl daemon-reload
systemctl enable backhaul-watchdog.timer || {
    echo -e "${RED}❌ Failed to enable backhaul-watchdog.timer${NC}"
    logger -t backhaul-watchdog "Failed to enable backhaul-watchdog.timer"
    exit 1
}
systemctl start backhaul-watchdog.timer || {
    echo -e "${RED}❌ Failed to start backhaul-watchdog.timer${NC}"
    logger -t backhaul-watchdog "Failed to start backhaul-watchdog.timer"
    exit 1
}

# Create CLI command
echo -e "${GREEN}🔗 Creating global 'watchdog' command...${NC}"
echo "bash $BASE_DIR/backhaul_watchdog.sh" > /usr/local/bin/watchdog
chmod +x /usr/local/bin/watchdog

# Run initial endpoint setup
echo -e "${GREEN}⚙️ Running initial endpoint setup...${NC}"
bash "$BASE_DIR/setup_endpoints.sh" || {
    echo -e "${RED}❌ Initial endpoint setup failed${NC}"
    logger -t backhaul-watchdog "Initial endpoint setup failed"
    exit 1
}

echo -e "${GREEN}✅ Installation complete! Use 'watchdog' to start the tool.${NC}"
logger -t backhaul-watchdog "Installation completed successfully"