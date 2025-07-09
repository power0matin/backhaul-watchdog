# 🔒 Backhaul Watchdog

A minimal, production-ready watchdog script to monitor IP:PORT endpoints and auto-restart your `backhaul` service on failures.  
Built for system administrators who demand simple, reliable uptime automation.

## ✨ Features

- Monitor endpoints via TLS, TCP, Ping, and cURL.
- Automatic restart of a backhaul service on failure.
- Cooldown-based restart control (prevents restart loops).
- Interactive control panel for configuration and management.
- Lightweight and dependency-friendly (just bash, curl, nc, ping, openssl).

## 🚀 Quick Install

Install with a single command:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/power0matin/backhaul-watchdog/main/install.sh)
```

Then run:

```bash
backhaul
```

And use the menu!

```

## 🛠 Configuration

Edit `backhaul_watchdog.conf`:

```

# Format: IP:PORT

192.168.1.1:443
8.8.8.8:53

````

## 🔁 Systemd Integration

The setup menu automatically creates a service:

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
````

## 📂 Files

| File                      | Description           |
| ------------------------- | --------------------- |
| `backhaul_watchdog.sh`    | Main watchdog script  |
| `config_example.conf`     | Example configuration |
| `systemd_example.service` | Example systemd unit  |
| `README.md`               | You're reading it     |
| `LICENSE`                 | MIT License           |

## 👨‍💻 Developer & Maintainer

This project was originally created by [MH-Zia](https://github.com/MH-Zia).

It has been actively maintained and enhanced by **[@powermatin](https://github.com/power0matin)**.

Feel free to open issues or contribute.

If you find this project helpful, please give it a ⭐️ star!


## 📜 License

MIT — Use it freely, even commercially. Just give credit!
