# HOW TO RUN BOUNZO ONLINE SERVER 24/7 (ANY NETWORK & WI-FI)

To make multiplayer work **"HOW ALL GAMES WORK"** (where players on 4G, 5G, or different Wi-Fi anywhere in the world connect using room codes without needing a PC), the game needs a public online server.

---

## ⚡ OPTION 1: Test Instantly Right Now (Free Public Tunnel)

You can test cross-network multiplayer (4G to Wi-Fi) immediately using your PC as the host:

1. Double click **`START_ONLINE_PLAYIT_TUNNEL.bat`** in the project folder.
2. It starts the local Godot server and opens a free [playit.gg](https://playit.gg) public tunnel.
3. Follow the one-time link on screen to claim your tunnel. Add a **UDP tunnel** for port **`7777`**.
4. You will get a free public internet address, for example:
   ```text
   bounzo.at.ply.gg:25432
   ```
5. In your mobile phone app, type that address into the **SERVER ADDRESS** box and tap **JOIN** or **CREATE ROOM**.
6. Both phones (one on 4G, one on Wi-Fi) can now play together across the internet!

---

## ☁️ OPTION 2: 24/7 Free Cloud Server (Fly.io / Docker — No PC Needed)

With Fly.io, the server runs **24/7 in the cloud** for free. Players never need a PC running.

The project is already pre-configured with `Dockerfile` and `fly.toml`!

### Steps to Deploy (Takes 3 Minutes):
1. Install the free Fly.io CLI (in PowerShell):
   ```powershell
   powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"
   ```
2. Log in / sign up (free):
   ```bash
   fly auth signup
   ```
3. In the project folder `c:\Users\moham\Desktop\BOUNZO MULTIPLAYER`, run:
   ```bash
   fly launch --no-deploy
   fly deploy
   ```
4. You will receive your public cloud address:
   ```text
   bounzo-server.fly.dev:7777
   ```
5. Put that address in **`server_config.json`**:
   ```json
   "client_defaults": {
     "default_server_host": "bounzo-server.fly.dev",
     "default_server_port": 7777
   }
   ```
6. Export the APK. Now **every player** who installs `BOUNZO.apk` automatically connects to the cloud server out-of-the-box on 4G, 5G, or Wi-Fi!

---

## 🖥️ OPTION 3: Dedicated Linux VPS (Oracle Cloud Free Tier, DigitalOcean, AWS)

If you have a Linux VPS (or Oracle Cloud Always Free VM):

1. Copy the project folder to your VPS: `/opt/bounzo-server`
2. Run with Godot Linux headless:
   ```bash
   godot --headless --path /opt/bounzo-server --scene res://scenes/multiplayer/server_main.tscn -- --port 7777
   ```
3. Open firewall port `7777/udp`:
   ```bash
   sudo ufw allow 7777/udp
   ```
4. Put your VPS public IP in `server_config.json`:
   ```json
   "default_server_host": "YOUR_VPS_PUBLIC_IP",
   "default_server_port": 7777
   ```
