# BOUNZO DEDICATED SERVER DEPLOYMENT GUIDE

This guide provides complete instructions for deploying the **BOUNZO Authoritative Dedicated Multiplayer Server** on a public Linux or Windows server.

---

## 1. Engine & Environment Requirements

- **Engine Version**: **Godot 4.7.1-stable** (Official headless binary)
- **Architecture**: Linux x86_64 (Ubuntu 22.04 LTS / 24.04 LTS recommended) or Windows Server
- **Protocol**: UDP (ENet Transport)
- **Default Port**: `7777` UDP
- **Minimum VPS Specs**:
  - 1 vCPU
  - 1 GB RAM
  - 10 GB SSD
  - 1 Public IPv4 address

> [!WARNING]
> **Hosting Clarification (Hostinger Shared Web Hosting vs VPS)**
> Shared website hosting (e.g., Hostinger cPanel/PHP shared web plans) cannot run long-running persistent background UDP game daemons. A Linux VPS (e.g., Hostinger VPS, Hetzner, DigitalOcean, Linode, AWS Lightsail, or Oracle Cloud Free Tier) is required to host the Godot headless server process.

---

## 2. Server Build & Export Steps

### Option A: Direct Headless Project Execution (Fastest & Recommended)
You do not need to compile custom C++ binaries. You can run the project files directly with the official Godot Linux headless runner:

1. Download the official Godot 4.7.1 Linux binary on the server:
   ```bash
   wget https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip
   unzip Godot_v4.7.1-stable_linux.x86_64.zip
   chmod +x Godot_v4.7.1-stable_linux.x86_64
   sudo mv Godot_v4.7.1-stable_linux.x86_64 /usr/local/bin/godot
   ```

2. Copy the project folder to `/opt/bounzo-server` on your VPS.

3. Run the headless server:
   ```bash
   godot --headless --path /opt/bounzo-server --scene res://scenes/multiplayer/server_main.tscn -- --port 7777
   ```

### Option B: Exporting a `.pck` Pack File
1. In Godot on your workstation, export a PCK file using the Linux preset:
   - Export Path: `bounzo_server.pck`
2. Copy `bounzo_server.pck` to your Linux server.
3. Run with the Godot binary:
   ```bash
   ./godot --headless --main-pack bounzo_server.pck --scene res://scenes/multiplayer/server_main.tscn -- --port 7777
   ```

---

## 3. Firewall & Networking Configuration

Allow incoming traffic on UDP port `7777`:

```bash
# Ubuntu UFW Firewall
sudo ufw allow 7777/udp
sudo ufw reload

# Check status
sudo ufw status
```

If using cloud providers with security groups (AWS, Google Cloud, Oracle Cloud, Azure), add an inbound security rule:
- **Protocol**: UDP
- **Port Range**: `7777`
- **Source**: `0.0.0.0/0` (Anywhere)

---

## 4. Systemd Service Setup (Auto-Restart & 24/7 Uptime)

Create a dedicated service file `/etc/systemd/system/bounzo-server.service`:

```ini
[Unit]
Description=BOUNZO Dedicated Multiplayer Game Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/bounzo-server
ExecStart=/usr/local/bin/godot --headless --scene res://scenes/multiplayer/server_main.tscn -- --port 7777
Restart=always
RestartSec=5
StandardOutput=append:/var/log/bounzo-server.log
StandardError=append:/var/log/bounzo-server.err
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable bounzo-server
sudo systemctl start bounzo-server

# Check service status
sudo systemctl status bounzo-server
```

---

## 5. Client Configuration (Connecting to Public Server)

In `res://server_config.json` inside the game project, set your server's public IP address or domain:

```json
{
  "client_defaults": {
    "default_server_host": "YOUR_SERVER_PUBLIC_IP",
    "default_server_port": 7777,
    "connection_timeout_seconds": 6.0
  }
}
```

Players can also type the server address directly into the lobby UI input field (`IP:PORT`).

---

## 6. Server Monitoring & Logs

View live server logs:
```bash
# Follow logs in real-time
journalctl -u bounzo-server -f

# Or view file logs
tail -f /var/log/bounzo-server.log
```

---

## 7. How to Test Across Two Different Internet Connections

1. **Host Client**: Connect phone to Cellular Data (5G/4G). Open BOUNZO, tap `ONLINE`, enter the public server IP, and tap `CREATE ROOM`. Note the 5-character room code (e.g., `BZ829`).
2. **Guest Client**: Connect a second phone or PC to Wi-Fi. Open BOUNZO, tap `ONLINE`, enter the same server IP, tap `JOIN WITH ROOM CODE`, enter `BZ829`, and tap `ENTER ROOM`.
3. Guest taps `READY!`. Host taps `START MATCH`.
4. Verify synchronized 3-2-1-GO countdown, live opponent movement, score tracking, elimination handling, and final podium rankings.
