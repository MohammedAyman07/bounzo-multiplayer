class_name MultiplayerProtocol
extends RefCounted

# ==============================================================================
# BOUNZO MULTIPLAYER PROTOCOL (Godot 4.7.1)
# Authoritative definitions, packet validation, and rate-limiting constants
# ==============================================================================

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS_PER_ROOM: int = 4
const MIN_PLAYERS_TO_START: int = 2
const ROOM_CODE_LENGTH: int = 5
const MAX_NAME_LENGTH: int = 14
const MIN_NAME_LENGTH: int = 2
const COUNTDOWN_SECONDS: float = 3.0
const MATCH_DURATION_SECONDS: float = 90.0
const MAX_PACKETS_PER_SECOND: int = 35
const POSITION_UPDATE_INTERVAL: float = 0.05 # 20 Hz update rate

# Room State Lifecycle
enum RoomState {
	LOBBY,
	COUNTDOWN,
	IN_GAME,
	RESULTS,
	CLOSED
}

# Player Match Status
enum PlayerStatus {
	ALIVE,
	ELIMINATED,
	FINISHED,
	DISCONNECTED
}

# Player Slot Colors (Neon Cyber Palette matching BOUNZO theme)
const SLOT_COLORS: Array[Color] = [
	Color(0.098, 0.851, 1.000, 1.0), # Slot 0: Cyber Cyan (#19D9FF)
	Color(1.000, 0.125, 0.784, 1.0), # Slot 1: Neon Magenta (#FF20C8)
	Color(1.000, 0.824, 0.122, 1.0), # Slot 2: Neon Yellow (#FFD21F)
	Color(0.224, 1.000, 0.533, 1.0)  # Slot 3: Toxic Green (#39FF88)
]

const SLOT_NAMES: Array[String] = ["CYAN", "MAGENTA", "YELLOW", "GREEN"]

# Valid characters for room codes (omits 0, O, 1, I to prevent user ambiguity)
const ROOM_CODE_CHARS: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

## Generate a unique 5-character alphanumeric room code
static func generate_room_code() -> String:
	var code: String = ""
	var chars_len: int = ROOM_CODE_CHARS.length()
	for i in range(ROOM_CODE_LENGTH):
		var idx: int = randi() % chars_len
		code += ROOM_CODE_CHARS[idx]
	return code

## Sanitize and validate player display name
static func sanitize_player_name(raw_name: String) -> String:
	var clean: String = ""
	for c in raw_name.strip_edges():
		if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == ' ' or c == '_':
			clean += c
	clean = clean.strip_edges()
	if clean.length() < MIN_NAME_LENGTH:
		clean = "Player_%d" % (randi() % 900 + 100)
	elif clean.length() > MAX_NAME_LENGTH:
		clean = clean.substr(0, MAX_NAME_LENGTH)
	return clean

## Validate room code format
static func is_valid_room_code_format(code: String) -> bool:
	var c = code.strip_edges().to_upper()
	if c.length() != ROOM_CODE_LENGTH:
		return false
	for char in c:
		if ROOM_CODE_CHARS.find(char) == -1:
			return false
	return true

const DISCOVERY_PORT: int = 7778

## Detect local Wi-Fi LAN IPv4 address
static func get_local_ip() -> String:
	var best_ip: String = ""
	for ip in IP.get_local_addresses():
		if ":" in ip: continue # skip IPv6
		if ip.begins_with("127."): continue # skip loopback
		if ip.begins_with("169.254."): continue # skip APIPA link-local
		if ip.begins_with("192.168.43."):
			return ip # Android Mobile Hotspot network
		if ip.begins_with("192.168."):
			best_ip = ip
		elif best_ip == "" and (ip.begins_with("10.") or ip.begins_with("172.")):
			best_ip = ip
	return best_ip if best_ip != "" else "127.0.0.1"

## Check if this device is connected to or hosting an Android mobile hotspot
static func is_hotspot_network() -> bool:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.43."):
			return true
	return false

## Standard Android mobile hotspot host IP
static func get_hotspot_host_ip() -> String:
	return "192.168.43.1"
