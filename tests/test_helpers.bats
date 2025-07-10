#!/usr/bin/env bats

setup() {
    load '/usr/local/bin/backhaul_watchdog/helpers.sh'
}

@test "validate_numeric should return true for valid numbers" {
    run validate_numeric "123"
    [ "$status" -eq 0 ]
}

@test "validate_numeric should return false for invalid numbers" {
    run validate_numeric "abc"
    [ "$status" -eq 1 ]
}

@test "validate_ip_or_domain should return true for valid IP" {
    run validate_ip_or_domain "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "validate_ip_or_domain should return true for valid domain" {
    run validate_ip_or_domain "example.com"
    [ "$status" -eq 0 ]
}

@test "validate_ip_or_domain should return false for invalid input" {
    run validate_ip_or_domain "invalid@domain"
    [ "$status" -eq 1 ]
}

@test "check_latency should return a number or unreachable" {
    run check_latency "8.8.8.8"
    [[ "$output" =~ ^[0-9.]+$ || "$output" == "unreachable" ]]
}