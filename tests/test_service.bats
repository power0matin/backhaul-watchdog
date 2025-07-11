#!/usr/bin/env bats

setup() {
    export PATH="/usr/sbin:/sbin:$PATH"
}

@test "systemd service file exists" {
    [ -f "/etc/systemd/system/backhaul-watchdog.service" ]
}

@test "systemd timer file exists" {
    [ -f "/etc/systemd/system/backhaul-watchdog.timer" ]
}

@test "systemd timer is enabled" {
    run systemctl is-enabled backhaul-watchdog.timer
    [ "$status" -eq 0 ]
    [ "$output" = "enabled" ]
}

@test "watchdog command exists" {
    [ -x "/usr/local/bin/watchdog" ]
}