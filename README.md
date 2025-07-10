
# 🔒 Backhaul Watchdog

A minimal, production-ready watchdog script to monitor IP:PORT endpoints and auto-restart your `backhaul` service on failures.  
Built for system administrators who demand simple, reliable uptime automation.


## ✨ Features

- ✅ Monitor endpoints via **TLS**, **TCP**, **Ping**, and **cURL**.
- 🔁 Automatic restart of a **Backhaul** service on failure.
- 🧠 Cooldown-based restart logic (prevents restart loops).
- ⚙️ Simple **interactive CLI menu** for configuration and management.
- 📦 Lightweight: Requires only basic tools (`bash`, `curl`, `nc`, `ping`, `openssl`).
- 🛡️ Designed with **security** and **stability** in mind.
- 🔒 Root-only by default for enhanced system control.


## 🚀 Quick Install

You can install Backhaul Watchdog with a single command:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/power0matin/backhaul-watchdog/main/install.sh)
```

After installation, launch the CLI menu using:

```bash
backhaul
```

And configure everything interactively.


## 🛠 Configuration

All endpoint monitoring is configured inside `backhaul_watchdog.conf`.

### Format:
```text
IP:PORT
```

### Example:
```text
192.168.1.1:443
8.8.8.8:53
google.com:443
```

The script parses this file and performs checks using different protocols depending on the port and type.


## 🔁 Systemd Integration

The CLI menu auto-generates and enables a `systemd` unit to run the watchdog in the background.

Example service file:

```ini
[Unit]
Description=Backhaul Watchdog Service
After=network.target

[Service]
ExecStart=/bin/bash /root/backhaul_watchdog.sh run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Use standard `systemctl` commands to manage it:

```bash
sudo systemctl restart backhaul
sudo systemctl stop backhaul
sudo systemctl status backhaul
```


## 📂 Project Structure

| File/Directory            | Description                            |
| ------------------------- | -------------------------------------- |
| `backhaul_watchdog.sh`    | Main watchdog script                   |
| `install.sh`              | One-liner installation script          |
| `uninstall.sh`            | Cleanup/uninstall script (optional)    |
| `config_example.conf`     | Example configuration file             |
| `backhaul_watchdog.conf`  | Active user configuration file         |
| `systemd_example.service` | Example systemd service unit           |
| `README.md`               | This file                              |
| `LICENSE`                 | MIT License                            |


## 👨‍💻 Developer & Maintainer

This project was originally created by [**MH-Zia**](https://github.com/MH-Zia).

It is now actively maintained and improved by [**@powermatin**](https://github.com/power0matin).  
Issues, contributions, and stars are welcome!


## 📜 License

This project is licensed under the **MIT License**.  
You can freely use, modify, and distribute it for personal or commercial purposes — just give credit.


## 🧹 Full Uninstall Instructions

To **completely remove** Backhaul Watchdog from your system:

```bash
# Remove the script and configuration files
sudo rm -rf /root/backhaul_watchdog.sh
sudo rm -rf /root/backhaul_watchdog.conf

# Optional: remove logs if any
sudo rm -f /var/log/backhaul_watchdog.log

echo "✅ Backhaul Watchdog has been fully uninstalled."
```

Or, if you've added an `uninstall.sh` script:

```bash
sudo bash uninstall.sh
```


> ⚠️ Note: Make sure to double-check file paths if you've customized them during install.


Thanks for using **Backhaul Watchdog** 🙌  
If you liked it, give it a ⭐️ star and share it with sysadmin friends!

