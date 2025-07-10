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
    exit 1
fi

echo -e "${CYAN}🔧 Starting Backhaul Watchdog installation...${NC}"

# Paths
BASE_DIR="/opt/backhaul_watchdog"
SCRIPT_DIR="$BASE_DIR/core"
CONFIG_DIR="$BASE_DIR/config"
SYSTEMD_DIR="/etc/systemd/system"
TEST_DIR="$BASE_DIR/tests"
BIN_LINK="/usr/local/bin/watchdog"
REPO_URL="https://github.com/power0matin/backhaul-watchdog"

# Dependencies check
for cmd in git curl bc; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ Required dependency '$cmd' is not installed.${NC}"
        exit 1
    fi
done

# Cleanup previous install
rm -rf "$BASE_DIR"
mkdir -p "$SCRIPT_DIR" "$CONFIG_DIR" "$TEST_DIR"

# Download files
echo -e "${GREEN}📥 Downloading files from GitHub...${NC}"

download() {
    local remote_path=$1
    local local_path=$2
    curl -Ls "$REPO_URL/raw/main/$remote_path" -o "$local_path" || {
        echo -e "${RED}❌ Failed to download $remote_path${NC}"
        exit 1
    }
    if [[ ! -s "$local_path" ]]; then
        echo -e "${RED}❌ File $remote_path is empty or invalid${NC}"
        exit 1
    fi
}

# Core scripts
for file in backhaul_watchdog.sh helpers.sh update.sh uninstall.sh setup_endpoints.sh; do
    download "core/$file" "$SCRIPT_DIR/$file"
done

# Config
download "config/config_example.conf" "$CONFIG_DIR/backhaul_watchdog.conf"
download "config/setup_endpoints.sh" "$CONFIG_DIR/setup_endpoints.sh"

# systemd files
for file in backhaul_watchdog.service backhaul_watchdog.timer; do
    download "systemd/$file" "$SYSTEMD_DIR/$file"
done

# Test files
for file in test_helpers.bats test_service.bats; do
    download "tests/$file" "$TEST_DIR/$file"
done

# Permissions
chmod +x "$SCRIPT_DIR/"*.sh "$CONFIG_DIR/setup_endpoints.sh"
chmod 600 "$CONFIG_DIR/backhaul_watchdog.conf"

# Enable systemd services
echo -e "${GREEN}🔄 Enabling systemd services...${NC}"
systemctl daemon-reload
systemctl enable backhaul_watchdog.timer
systemctl start backhaul_watchdog.timer

# Create CLI command
echo -e "${GREEN}🔗 Creating global 'watchdog' command...${NC}"
echo "bash $SCRIPT_DIR/backhaul_watchdog.sh" > "$BIN_LINK"
chmod +x "$BIN_LINK"

# Run initial setup
echo -e "${GREEN}⚙️ Running initial endpoint setup...${NC}"
bash "$CONFIG_DIR/setup_endpoints.sh" || {
    echo -e "${RED}❌ Initial setup failed${NC}"
    exit 1
}

echo -e "${GREEN}✅ Installation complete! Run the tool with 'watchdog'.${NC}"