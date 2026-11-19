# 🚀 BOUNZO MULTIPLAYER — 100% FREE PUBLISH & HOSTING HANDBOOK

This guide explains **how players connect when published to Google Play / public release** and how to host the game server **100% FREE forever (0$ cost, no credit card required)**.

---

## 📱 1. HOW PLAYERS CONNECT IN PUBLIC

When regular players download BOUNZO from Google Play:
1. **Player 1** (e.g. on 4G Mobile Data):
   - Opens BOUNZO -> taps **ONLINE**.
   - Types their name (e.g. `ShadowBouncer`).
   - Taps **`[ CREATE ROOM ]`**.
   - The game connects to the server and generates a 5-letter Room Code: e.g. **`BZ892`**.
   - Player 1 taps **`[ COPY CODE ]`** and shares `BZ892` via WhatsApp, Discord, or SMS.

2. **Player 2** (e.g. on Home Wi-Fi anywhere in the world):
   - Opens BOUNZO -> taps **ONLINE**.
   - Taps **`[ JOIN ROOM WITH CODE ]`**.
   - Enters **`BZ892`** and taps **`[ ENTER ROOM ]`**.

3. **In the Lobby**:
   - Both players see each other's custom ball skins.
   - Host chooses the Match Goal: **2000, 3000, 5000 pts (Race)** or **Survival (Last Man Standing)**.
   - Player 2 taps **`[ READY! ]`**, Host taps **`[ START MATCH ]`**!
   - 3.. 2.. 1.. GO! They race up the 500 obstacle platforms (moving, spikes, fragile, vanishing) with Last Man Standing rules!

> Normal players **never** have to type IP addresses or port numbers. Everything connects automatically!

---

## 🌐 2. WHY A PUBLIC SERVER IS NEEDED FOR 4G/5G

Mobile phone carriers (Airtel, Jio, AT&T, Vodafone, etc.) place all phones behind **Carrier-Grade NAT (CGNAT)** and firewalls. Two phones on cellular data cannot connect directly to each other's internal IP (`10.x.x.x` or `192.168.x.x`).

Therefore, mobile games connect through a **public server router** that relays room codes and positions.

Below are the two ways to host this server **100% FREE**.

---

## ⚡ 3. OPTION A: INSTANT 1-CLICK FREE TUNNEL (Playit.gg)
*Best for testing cross-network (4G to Wi-Fi) immediately without any setup.*

We have already downloaded `playit.exe` into your project!

1. In the project folder, double-click:
   ```cmd
   START_ONLINE_PLAYIT_TUNNEL.bat
   ```
2. It starts the Godot server and launches `playit.exe`.
3. Follow the one-time link in the terminal to claim your free tunnel.
4. Add a **UDP Tunnel** pointing to port **`7777`**.
5. You will get a free permanent address like:
   ```text
   bounzo.auto.playit.gg:19245
   ```
6. Put that address in `server_config.json`:
   ```json
   "client_defaults": {
     "default_server_host": "bounzo.auto.playit.gg",
     "default_server_port": 19245
   }
   ```

---

## ☁️ 4. OPTION B: 24/7 FREE CLOUD SERVER (Fly.io — No PC Needed)
*Best for Google Play publishing: runs 24/7 in the cloud with no computer turned on.*

The project already contains `Dockerfile` and `fly.toml` ready to deploy!

### 3-Minute Deployment Steps:
1. Open PowerShell and install the free Fly CLI:
   ```powershell
   powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"
   ```
2. Sign up / log in (free):
   ```bash
   fly auth signup
   ```
3. Inside `c:\Users\moham\Desktop\BOUNZO MULTIPLAYER`, run:
   ```bash
   fly launch --no-deploy
   fly deploy
   ```
4. You will get your free cloud address:
   ```text
   bounzo-multiplayer.fly.dev:7777
   ```
5. Put that address in `server_config.json`:
   ```json
   "client_defaults": {
     "default_server_host": "bounzo-multiplayer.fly.dev",
     "default_server_port": 7777
   }
   ```

---

## 🔄 5. DYNAMIC REMOTE CONFIG (Zero-App-Update Feature)
*How to change servers without re-uploading an APK to Google Play Store!*

We added **Dynamic Remote Config** to `MultiplayerManager.gd`:

1. Create a free GitHub Gist, public GitHub repository file, or pastebin containing:
   ```json
   {
     "server_host": "bounzo-multiplayer.fly.dev",
     "server_port": 7777
   }
   ```
2. Get the **Raw URL** (e.g. `https://raw.githubusercontent.com/yourname/bounzo-config/main/server.json`).
3. In `server_config.json`, set:
   ```json
   "client_defaults": {
     "remote_config_url": "https://raw.githubusercontent.com/yourname/bounzo-config/main/server.json"
   }
   ```
4. **Whenever you change or restart your free server in the future**, simply edit that 1 line in your GitHub file. **All players worldwide will instantly route to the new server** without downloading a single game update!

---

## 📶 6. OFFLINE / HOTSPOT BACKUP

If players are on an airplane, in school, or have no internet access, they can still play!
- Tap **`[ ⚙️ ADVANCED / LOCAL NETWORK ]`** at the bottom of the lobby.
- One player taps **`HOST OFFLINE ON PHONE (HOTSPOT)`**.
- Nearby friends connect via Wi-Fi Auto-Discovery or enter the Hotspot host IP.
