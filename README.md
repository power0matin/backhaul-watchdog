````markdown
# 🔒 Backhaul Watchdog

A minimal, production-ready watchdog script to monitor IP:PORT endpoints and auto-restart your `backhaul` service on failures.  
Built for system administrators who demand simple, reliable uptime automation.

## ✨ Features

- Monitor endpoints via TLS, TCP, Ping, and cURL.
- Automatic restart of a backhaul service on failure.
- Cooldown-based restart control (prevents restart loops).
- Interactive control panel for configuration and management.
- Lightweight and dependency-friendly (just bash, curl, nc, ping, openssl).

## ⚙️ Setup

1. Clone this repo:
   ```bash
   git clone https://github.com/powermatin/backhaul-watchdog
   cd backhaul-watchdog
   ```
````

2. Run the setup menu:

   ```bash
   sudo bash backhaul_watchdog.sh
   ```

3. Choose option `[1]` to add endpoints and install the systemd service.

## 🛠 Configuration

Edit `backhaul_watchdog.conf`:

```
# Format: IP:PORT
192.168.1.1:443
8.8.8.8:53
```

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
```

## 📂 Files

| File                      | Description           |
| ------------------------- | --------------------- |
| `backhaul_watchdog.sh`    | Main watchdog script  |
| `config_example.conf`     | Example configuration |
| `systemd_example.service` | Example systemd unit  |
| `README.md`               | You're reading it     |
| `LICENSE`                 | MIT License           |

## 👨‍💻 Developer

Developed with care by **[@powermatin](https://github.com/powermatin)**
Feel free to open issues or contribute.

## 📜 License

MIT — Use it freely, even commercially. Just give credit!

