#!/usr/bin/env bats

setup() {
    load '/usr/local/bin/backhaul_watchdog/helpers.sh'
    export PATH="/usr/sbin:/sbin:$PATH"
}

@test "validate_ip_or_domain accepts valid IP" {
    run validate_ip_or_domain "8.8.8.8"
    [ "$status" -eq 0 ]
}

@test "validate_ip_or_domain accepts valid domain" {
    run validate_ip_or_domain "google.com"
    [ "$status" -eq 0 ]
}

@test "validate_ip_or_domain rejects invalid input" {
    run validate_ip_or_domain "invalid"
    [ "$status" -eq 1 ]
}

@test "validate_numeric accepts valid number" {
    run validate_numeric "123"
    [ "$status" -eq 0 ]
}

@test "validate_numeric rejects non-numeric input" {
    run validate_numeric "abc"
    [ "$status" -eq 1 ]
}

@test "check_root fails for non-root user" {
    if [[ $EUID -eq 0 ]]; then
        skip "Test requires non-root user"
    fi
    run check_root
    [ "$status" -eq 1 ]
    [[ "$output" =~ "This script must be run as root" ]]
}

@test "load_config fails for non-existent file" {
    run load_config "/nonexistent/config"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Configuration file /nonexistent/config not found" ]]
}