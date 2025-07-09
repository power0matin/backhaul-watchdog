#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "🚨 لطفاً اسکریپت را با دسترسی root اجرا کنید."
  exit 1
fi

CONFIG_FILE="/root/backhaul_watchdog.conf"
SERVICE_FILE="/etc/systemd/system/backhaul_watchdog.service"
LOG_FILE="/var/log/backhaul_watchdog.log"
MODE="$1"

BOLD='\e[1m'; NC='\e[0m'
RED='\e[91m'; GREEN='\e[92m'; YELLOW='\e[93m'
BLUE='\e[94m'; MAGENTA='\e[95m'; CYAN='\e[96m'; GRAY='\e[90m'

# تابع اعتبارسنجی فرمت IP:PORT
validate_endpoint() {
  local ep=$1
  if [[ "$ep" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$ ]]; then
    # چک کردن هر بخش IP که <= 255 باشد
    IFS=':' read -r ip port <<< "$ep"
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        return 1
      fi
    done
    # چک کردن محدوده پورت
    if ((port > 0 && port <= 65535)); then
      return 0
    fi
  fi
  return 1
}

print_help() {
  clear
  echo -e "${CYAN}${BOLD}راهنمای کامل استفاده از Backhaul Watchdog${NC}"
  echo
  echo "این پروژه برای مانیتورینگ و نگهداری اتصال تانل‌های سرور ایران به خارج طراحی شده است."
  echo "اگر پینگ یا اتصال به هر یک از سرورهای تعیین شده بالا رفت یا قطع شد، سرویس به صورت خودکار تانل را ریستارت می‌کند."
  echo
  echo "گزینه‌ها در منوی اصلی:"
  echo " 1. Initial setup (add endpoints): در این قسمت باید IP و پورت سرورهای خود را به فرمت IP:PORT وارد کنید."
  echo "    مثال: 192.168.1.1:443"
  echo "    توجه داشته باشید که اگر فرمت اشتباه باشد، دوباره از شما درخواست می‌شود تا ورودی صحیح وارد کنید."
  echo
  echo " 2. Edit configuration file: اگر می‌خواهید لیست سرورها را به صورت دستی ویرایش کنید، این گزینه را انتخاب کنید."
  echo
  echo " 3. Restart watchdog service: این گزینه باعث می‌شود سرویس مانیتورینگ مجدداً راه‌اندازی شود."
  echo
  echo " 4. Remove service and config file: برای حذف کامل سرویس و فایل‌های تنظیمات استفاده می‌شود."
  echo
  echo " 0. Exit menu: خروج از منوی کنترل."
  echo
  echo "برای اجرای مانیتورینگ اصلی اسکریپت، کافی است سرویس systemd به صورت خودکار اجرا شود."
  echo
  echo "هر گونه سوال یا مشکل داشتید، با توسعه‌دهنده @powermatin تماس بگیرید."
  echo
  read -p "برای بازگشت به منو کلید Enter را بزنید..."
}

# ======================== Menu ========================
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
    printf "│ ${GRAY}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Help (راهنما)" "[5]"
    printf "│ ${GRAY}%-54s${NC} ${YELLOW}${BOLD}%6s${NC} │\n" "Exit menu" "[0]"
    echo -e "${NC}"
    read -p "$(echo -e ${MAGENTA}${BOLD}👉 Select an option by number: ${NC})" choice

    case "$choice" in
      1)
        echo "# Backhaul endpoints config file" > "$CONFIG_FILE"
        echo "💡 چند سرور می‌خواهید اضافه کنید؟"
        read -r COUNT
        if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || (( COUNT <= 0 )); then
          echo -e "${RED}❌ تعداد معتبر نیست. به منو باز می‌گردیم.${NC}"
          sleep 2
          continue
        fi

        for ((i=1; i<=COUNT; i++)); do
          while true; do
            read -p "🔹 وارد کردن endpoint شماره $i (فرمت IP:PORT): " line
            if validate_endpoint "$line"; then
              echo "$line" >> "$CONFIG_FILE"
              break
            else
              echo -e "${RED}⚠️ فرمت اشتباه است. لطفاً دوباره وارد کنید.${NC}"
            fi
          done
        done

        echo -e "${BLUE}🛠 ایجاد سرویس systemd...${NC}"
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
        echo -e "${GREEN}✅ سرویس با موفقیت راه‌اندازی شد.${NC}"
        echo "💡 برای اعمال تغییرات بهتر است سیستم خود را ریستارت کنید."
        read -p "برای بازگشت به منو کلید Enter را بزنید..."
        ;;
      2)
        if [ ! -f "$CONFIG_FILE" ]; then
          echo -e "${RED}⚠️ فایل تنظیمات وجود ندارد. ابتدا گزینه 1 را اجرا کنید.${NC}"
          sleep 2
          continue
        fi
        nano "$CONFIG_FILE"
        echo "💡 برای اعمال تغییرات بهتر است سیستم خود را ریستارت کنید."
        read -p "برای بازگشت به منو کلید Enter را بزنید..."
        ;;
      3)
        systemctl restart backhaul_watchdog.service
        echo "$(date '+%Y-%m-%d %H:%M:%S') سرویس Watchdog به صورت دستی ریستارت شد." >> "$LOG_FILE"
        echo -e "${GREEN}✅ سرویس Watchdog ریستارت شد.${NC}"
        read -p "برای بازگشت به منو کلید Enter را بزنید..."
        ;;
      4)
        systemctl stop backhaul_watchdog.service
        systemctl disable backhaul_watchdog.service
        rm -f "$SERVICE_FILE" "$CONFIG_FILE"
        systemctl daemon-reload
        echo "$(date '+%Y-%m-%d %H:%M:%S') سرویس Watchdog و فایل‌های تنظیمات حذف شدند." >> "$LOG_FILE"
        echo -e "${RED}🗑️ سرویس و فایل‌های تنظیمات حذف شدند.${NC}"
        read -p "برای بازگشت به منو کلید Enter را بزنید..."
        ;;
      5)
        print_help
        ;;
      0)
        echo "👋 خداحافظ!"
        exit 0
        ;;
      *)
        echo -e "${RED}❌ گزینه نامعتبر است.${NC}"
        sleep 1.5
        ;;
    esac
  done
  exit 0
fi

# ======================== Monitoring Mode ========================

RESTART_COOLDOWN=300  # ثانیه‌ها بین ریستارت‌های متوالی
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

# چک می‌کنیم فایل کانفیگ وجود داشته باشه و حداقل یک endpoint داشته باشه
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}❌ فایل تنظیمات یافت نشد. لطفاً ابتدا از منو endpoints اضافه کنید.${NC}"
  exit 1
fi

ENDPOINTS_COUNT=$(grep -v '^#' "$CONFIG_FILE" | grep -c '.')
if (( ENDPOINTS_COUNT == 0 )); then
  echo -e "${RED}❌ هیچ endpoint ای برای مانیتورینگ وجود ندارد. لطفاً ابتدا از منو endpoints اضافه کنید.${NC}"
  exit 1
fi

while true; do
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    if ! [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
      log "⚠️ خط نامعتبر در فایل تنظیمات رد شد: $line"
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
          log "🔁 در حال ریستارت backhaul از طریق systemctl"
          systemctl restart backhaul.service
          log "✔️ backhaul با موفقیت ریستارت شد"
        else
          log "⚠️ سرویس backhaul فعال نیست، امکان ریستارت نیست"
        fi
        LAST_RESTART=$CURRENT_TIME
      else
        log "⏳ زمان بین ریستارت‌ها کافی نیست، ریستارت رد شد"
      fi
    else
      log "✅ اتصال سالم برای $IP:$PORT"
    fi
  done < "$CONFIG_FILE"

  sleep 90
done
