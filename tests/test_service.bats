#!/usr/bin/env bats

setup() {
    CONFIG_FILE="/etc/backhaul_watchdog/backhaul_watchdog.conf"
    cat > "$CONFIG_FILE" <<EOF
PING_TARGETS="8.8.8.8"
MAX_LATENCY=200
CHECK_INTERVAL=30
SERVICE_NAME="backhaul"
COOLDOWN=300
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
EOF
}

teardown() {
    rm -f "$CONFIG_FILE"
}

@test "watchdog_loop should run without errors" {
    run bash /usr/local/bin/backhaul_watchdog/backhaul_watchdog.sh --watchdog
    [ "$status" -eq 0 ]
}

@test "watchdog_loop should detect unreachable target" {
    echo "PING_TARGETS=\"invalid.target\"" > "$CONFIG_FILE"
    run bash /usr/local/bin/backhaul_watchdog/backhaul_watchdog.sh --watchdog
    [[ "$output" =~ "Ping to invalid.target failed" ]]
}