# BOUNZO ONLINE MULTIPLAYER — IMPLEMENTATION PLAN

## 1. Actual Relevant Files and Scene Paths
- Engine Executable: `Godot_v4.7.1-stable_win64_console.exe` (v4.7.1.stable.official.a13da4feb)
- Project Config: `res://project.godot`
- Export Presets: `res://export_presets.cfg` (`package/unique_name="com.ayzus.bounzo"`, `permissions/internet=true` enabled)
- Splash Screen: `res://scenes/splash/splash.tscn` / `res://scripts/splash.gd`
- Game & HUD Scene: `res://scenes/game/game.tscn` / `res://scripts/game.gd`
- UI Design System: `res://scripts/ui_theme.gd`, `res://scripts/ui_builder.gd`, `res://scripts/ui_icon.gd`
- Player Controller: `res://scenes/player/player.tscn` / `res://scripts/player.gd`, `res://scripts/player_visual.gd`
- Platform Generation: `res://scenes/platform/platform.tscn` / `res://scripts/platform.gd`, `res://scripts/platform_generator.gd`
- Camera: `res://scripts/camera_controller.gd`
- Cosmetics: `res://scripts/cosmetic_data.gd`
- Save System: `res://scripts/save_manager.gd` (Save format v5 in `user://save_data.json`)
- AdMob Integration: `res://scripts/ad_manager.gd`, `res://addons/AdmobPlugin/Admob.gd`

## 2. Current Architecture & Dependencies
- Single-player game loops entirely inside `game.tscn` with `game.gd` handling state transitions (`MENU`, `PLAYING`, `GAME_OVER`, `PAUSED`, `COUNTDOWN`).
- Menus (Shop, Daily, Missions, Challenges, Settings) are generated dynamically by `ui_builder.gd` in a 2-column grid.
- Input: `InputEventScreenTouch`, `InputEventScreenDrag`, left/right screen half touch steering.
- Platform generator spawns platforms upwards (decreasing Y coordinate) with dynamic difficulty curves.
- Strict save data validation protects coins, rank stars, cosmetic unlocks, and missions against corruption.

## 3. Proposed New Files
- `res://scripts/multiplayer/multiplayer_protocol.gd`: Authoritative RPC signatures, packet validation, rate limiting, and room code generator.
- `res://scripts/multiplayer/multiplayer_manager.gd`: Client network lifecycle, server connection, error handling, and latency tracking.
- `res://scripts/multiplayer/room_manager.gd`: Server-side room registry (5-char code, max 4 players, lifecycle states, cleanup).
- `res://scripts/multiplayer/match_manager.gd`: Authoritative match orchestration, synchronized countdown, course seed distribution, position tracking, speed validation, and tie-breaking results.
- `res://scripts/multiplayer/dedicated_server.gd`: Headless server controller, CLI argument parsing, port binding (default 7777 UDP).
- `res://scripts/multiplayer/multiplayer_platform_generator.gd`: Seeded deterministic course generator ensuring identical platforms for all 4 racers.
- `res://scripts/multiplayer/remote_player.gd`: Opponent avatar presentation with player slot colors (Cyan, Magenta, Yellow, Green), cosmetics, overhead nametag, and smooth interpolation.
- `res://scripts/multiplayer/multiplayer_game.gd`: In-game multiplayer controller, touch controls, race tracker progress bar, opponent cards, and spectator mode.
- `res://scripts/multiplayer/multiplayer_lobby_ui.gd`: Room creation, room code entry, 4-slot player cards, ready status, and start match control.
- `res://scenes/multiplayer/server_main.tscn`: Dedicated server entry scene.
- `res://scenes/multiplayer/multiplayer_lobby.tscn`: Clean lobby scene matching BOUNZO's cyber neon aesthetic.
- `res://scenes/multiplayer/multiplayer_game.tscn`: 4-player Survival Race arena scene.
- `res://scenes/multiplayer/remote_player.tscn`: Remote player ghost/avatar instance.
- `res://scenes/multiplayer/multiplayer_results.tscn`: End of match rankings and podium screen.
- `res://server_config.json`: Server configuration template (port, max rooms, tickrate).
- `res://test_multiplayer.gd`: Automated headless integration test suite.
- `SERVER_DEPLOYMENT.md`: Production deployment guide for Linux VPS.
- `MULTIPLAYER_TEST_REPORT.md`: Comprehensive test results.

## 4. Potential Compatibility Risks & Mitigation
- **Risk**: Modifying existing single-player code could introduce physics bugs or break endless mode.
  - *Mitigation*: Single-player scenes and scripts remain untouched. Multiplayer uses separate scenes and scripts, only referencing existing `UITheme`, `CosmeticData`, and platform visual assets.
- **Risk**: AdMob banner interfering with multiplayer UI.
  - *Mitigation*: Explicitly call `AdManager.hide_banner()` when entering multiplayer lobby or match.
- **Risk**: Save data corruption from multiplayer results.
  - *Mitigation*: Multiplayer match results do not alter single-player coins, ranks, or challenges.
- **Risk**: Unauthoritative client cheats or position manipulation.
  - *Mitigation*: Dedicated authoritative server validates packet rates, player membership, speed thresholds, course seeds, and match results.

## 5. Test & Deployment Plan
1. Automated test suite (`test_multiplayer.gd`) run via `Godot_v4.7.1-stable_win64_console.exe --headless`.
2. Multi-client local verification: Dedicated server + 2 to 4 clients connected simultaneously.
3. Linux headless deployment documentation with systemd unit, UFW rules, and external network test procedure.
