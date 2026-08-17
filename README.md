# 🔒 Backhaul Watchdog

<!-- repo-badges:start -->
<p align="center">
  <a href="https://hits.sh/github.com/power0matin/backhaul-watchdog/"><img src="https://hits.sh/github.com/power0matin/backhaul-watchdog.svg?style=flat-square&amp;label=Views&amp;labelColor=18181B&amp;color=0EA5E9&amp;logo=github" alt="Repository Views"/></a>
  <a href="https://github.com/power0matin/backhaul-watchdog/stargazers"><img src="https://img.shields.io/github/stars/power0matin/backhaul-watchdog?style=flat-square&amp;label=Stars&amp;labelColor=18181B&amp;color=F59E0B&amp;logo=github&amp;logoColor=white" alt="GitHub Stars"/></a>
  <a href="https://github.com/power0matin/backhaul-watchdog/forks"><img src="https://img.shields.io/github/forks/power0matin/backhaul-watchdog?style=flat-square&amp;label=Forks&amp;labelColor=18181B&amp;color=6366F1&amp;logo=github&amp;logoColor=white" alt="GitHub Forks"/></a>
  <a href="https://github.com/power0matin/backhaul-watchdog/issues"><img src="https://img.shields.io/github/issues/power0matin/backhaul-watchdog?style=flat-square&amp;label=Issues&amp;labelColor=18181B&amp;color=22C55E&amp;logo=github&amp;logoColor=white" alt="GitHub Issues"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/power0matin/backhaul-watchdog?style=flat-square&amp;label=License&amp;labelColor=18181B&amp;color=EF4444&amp;logo=github&amp;logoColor=white" alt="GitHub License"/></a>
</p>
<!-- repo-badges:end -->

A minimal, **production-ready** watchdog script to monitor `IP:PORT` endpoints and **auto-restart** your `backhaul` service on failures.
Built for system administrators who need **simple**, **reliable** uptime automation.


## ✨ Features

* ✅ Monitor endpoints via **TLS**, **TCP**, **Ping**, and **cURL**
* 🔁 Automatic restart of **Backhaul** service on failure
* 🧠 Cooldown-based restart logic (prevents restart loops)
* ⚙️ Simple **interactive CLI menu** for configuration and management
* 📦 Lightweight — requires only basic tools (`bash`, `curl`, `nc`, `ping`, `openssl`)
* 🛡️ Designed for **security** and **stability**
* 🔒 Runs as root by default for enhanced system control


## 🚀 Quick Install

Install Backhaul Watchdog with a single command:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/power0matin/backhaul-watchdog/main/install.sh)
```

Then launch the interactive CLI:

```bash
watchdog
```

Configure everything directly through the menu.


## 🛠 Configuration

All endpoints are configured in `backhaul_watchdog.conf`.

### Format

```
IP:PORT
```

### Example

```
192.168.1.1:443
8.8.8.8:53
google.com:443
```

The script parses this file and runs appropriate checks based on protocol and port type.


## 🔁 Systemd Integration

The CLI menu can auto-generate and enable a `systemd` unit to run the watchdog in the background.

### Example service file

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

### Commands

Restart / Stop:

```bash
sudo systemctl restart backhaul-watchdog
sudo systemctl stop backhaul-watchdog
sudo systemctl status backhaul-watchdog
```

Start / Enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable backhaul-watchdog.service
sudo systemctl start backhaul-watchdog.service
sudo systemctl enable backhaul-watchdog.timer
sudo systemctl start backhaul-watchdog.timer
```


## 📂 Project Structure

| File / Directory          | Description                   |
| ------------------------- | ----------------------------- |
| `backhaul_watchdog.sh`    | Main watchdog script          |
| `install.sh`              | One-liner installation script |
| `uninstall.sh`            | Optional cleanup script       |
| `config_example.conf`     | Example configuration file    |
| `backhaul_watchdog.conf`  | Active user configuration     |
| `systemd_example.service` | Example systemd unit          |
| `README.md`               | Project documentation         |
| `LICENSE`                 | MIT License                   |


## 👨‍💻 Developer & Maintainer

Originally created by [**MH-Zia**](https://github.com/MH-Zia).
Now actively maintained and improved by [**@powermatin**](https://github.com/power0matin).

👉 Issues, pull requests, and ⭐ stars are welcome!


## 📜 License

This project is licensed under the **MIT License**.
You can use, modify, and distribute it freely — just give credit.


## 🧹 Full Uninstall Instructions

To completely remove Backhaul Watchdog:

```bash
# Remove scripts and configuration
sudo rm -rf /root/backhaul_watchdog.sh
sudo rm -rf /root/backhaul_watchdog.conf

# Optional: remove logs
sudo rm -f /var/log/backhaul_watchdog.log

echo "✅ Backhaul Watchdog has been fully uninstalled."
```

Or if you used the provided uninstall script:

```bash
sudo bash /usr/local/bin/backhaul_watchdog/uninstall.sh
rm -rf /usr/local/bin/backhaul_watchdog /etc/backhaul_watchdog /etc/systemd/system/backhaul-watchdog.*
```

> ⚠️ **Note**: Double-check paths if you changed them during installation.

## 📬 Contact

**Matin Shahabadi (متین شاه‌آبادی / متین شاه آبادی)**

* Website: [matinshahabadi.ir](https://matinshahabadi.ir)
* Email: [me@matinshahabadi.ir](mailto:me@matinshahabadi.ir)
* GitHub: [power0matin](https://github.com/power0matin)
* LinkedIn: [matin-shahabadi](https://www.linkedin.com/in/matin-shahabadi)

✨ Thanks for using **Backhaul Watchdog** 🙌
If you find it useful, don’t forget to **⭐ star the repo** and share it with fellow sysadmins.
