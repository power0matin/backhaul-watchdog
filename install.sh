#!/bin/bash

set -euo pipefail

BIN_PATH="/usr/local/bin/backhaul-watchdog"
CLI_ALIAS="/usr/local/bin/watchdog"
SERVICE_PATH="/etc/systemd/system/backhaul_watchdog.service"
CONFIG_PATH="/root/backhaul_watchdog.conf"
REPO_URL="https://raw.githubusercontent.com/power0matin/backhaul-watchdog/main/core"

# رنگ‌ها برای نمایش پیام‌ها
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
NC="\033[0m"

# چک کردن دسترسی sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Please run as root or use sudo.${NC}"
  exit 1
fi

echo -e "${GREEN}🚀 Installing Backhaul Watchdog...${NC}"

# دانلود اسکریپت اصلی
if curl -fsSL "$REPO_URL/backhaul_watchdog.sh" -o "$BIN_PATH"; then
  chmod +x "$BIN_PATH"
else
  echo -e "${YELLOW}Failed to download backhaul_watchdog.sh${NC}"
  exit 1
fi

# ساخت شورتکات CLI
cat > "$CLI_ALIAS" <<EOF
#!/bin/bash
bash $BIN_PATH "\$@"
EOF
chmod +x "$CLI_ALIAS"

# دانلود کانفیگ نمونه اگر وجود نداشت
if [ ! -f "$CONFIG_PATH" ]; then
  if ! curl -fsSL "$REPO_URL/config_example.conf" -o "$CONFIG_PATH"; then
    echo -e "${YELLOW}Failed to download default config file${NC}"
    exit 1
  fi
fi

# دانلود فایل سرویس systemd
if curl -fsSL "$REPO_URL/systemd_example.service" -o "$SERVICE_PATH"; then
  systemctl daemon-reload
  systemctl enable backhaul_watchdog
  systemctl restart backhaul_watchdog
else
  echo -e "${YELLOW}Failed to download or enable systemd service${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Installed successfully!${NC}"
echo -e "👉 You can now run it using: ${YELLOW}watchdog${NC}"
