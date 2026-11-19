class_name LANBeacon
extends Node

# ==============================================================================
# BOUNZO LAN AUTO-DISCOVERY BEACON (Godot 4.7.1)
# Broadcasts active LAN rooms via UDP and auto-discovers games on the local Wi-Fi.
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")

signal rooms_updated(rooms: Dictionary)

var _broadcaster: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _broadcast_timer: float = 0.0
var _cleanup_timer: float = 0.0

var is_broadcasting: bool = false
var is_listening: bool = false

var broadcast_data: Dictionary = {}
var discovered_rooms: Dictionary = {} # code -> { info: Dictionary, last_seen: float }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_broadcasting and _broadcaster != null:
		_broadcast_timer += delta
		if _broadcast_timer >= 1.0:
			_broadcast_timer = 0.0
			_send_broadcast_packet()

	if is_listening and _listener != null:
		_poll_listener()

		_cleanup_timer += delta
		if _cleanup_timer >= 1.0:
			_cleanup_timer = 0.0
			_prune_expired_rooms()

## Start broadcasting this host room on local Wi-Fi
func start_broadcasting(room_code: String, host_name: String, host_port: int, player_count: int = 1) -> void:
	stop_broadcasting()

	var local_ip = Protocol.get_local_ip()
	broadcast_data = {
		"game": "BOUNZO",
		"code": room_code,
		"host": host_name,
		"ip": local_ip,
		"port": host_port,
		"count": player_count
	}

	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	var err = _broadcaster.set_dest_address("255.255.255.255", Protocol.DISCOVERY_PORT)
	if err == OK:
		is_broadcasting = true
		_broadcast_timer = 0.9 # Send immediately
		print("[LANBeacon] Broadcasting LAN room %s on port %d" % [room_code, Protocol.DISCOVERY_PORT])
	else:
		printerr("[LANBeacon] Failed to setup UDP broadcast: %d" % err)

func update_player_count(count: int) -> void:
	if broadcast_data.has("count"):
		broadcast_data["count"] = count

func stop_broadcasting() -> void:
	is_broadcasting = false
	if _broadcaster != null:
		_broadcaster.close()
		_broadcaster = null
	broadcast_data.clear()

## Start listening for active LAN rooms on local Wi-Fi
func start_listening() -> void:
	if is_listening: return

	_listener = PacketPeerUDP.new()
	var err = _listener.bind(Protocol.DISCOVERY_PORT)
	if err == OK:
		is_listening = true
		discovered_rooms.clear()
		print("[LANBeacon] Listening for LAN games on UDP port %d" % Protocol.DISCOVERY_PORT)
	else:
		print("[LANBeacon] Discovery port %d unavailable or already bound (err %d)" % [Protocol.DISCOVERY_PORT, err])
		_listener = null

func stop_listening() -> void:
	is_listening = false
	if _listener != null:
		_listener.close()
		_listener = null
	discovered_rooms.clear()

func _send_broadcast_packet() -> void:
	if _broadcaster == null or broadcast_data.is_empty(): return
	var json_str = JSON.stringify(broadcast_data)
	_broadcaster.put_packet(json_str.to_utf8_buffer())

func _poll_listener() -> void:
	if _listener == null: return
	var changed: bool = false
	var now = Time.get_ticks_msec() / 1000.0

	while _listener.get_available_packet_count() > 0:
		var pkt = _listener.get_packet()
		var text = pkt.get_string_from_utf8()
		var json = JSON.new()
		if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var data: Dictionary = json.data
			if data.get("game", "") == "BOUNZO" and data.has("code") and data.has("ip"):
				var code: String = data.get("code", "")
				discovered_rooms[code] = {
					"info": data,
					"last_seen": now
				}
				changed = true

	if changed:
		_emit_update()

func _prune_expired_rooms() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var to_remove: Array = []
	for code in discovered_rooms.keys():
		var entry = discovered_rooms[code]
		if (now - entry.last_seen) > 3.5:
			to_remove.append(code)

	if to_remove.size() > 0:
		for code in to_remove:
			discovered_rooms.erase(code)
		_emit_update()

func _emit_update() -> void:
	var result: Dictionary = {}
	for code in discovered_rooms.keys():
		result[code] = discovered_rooms[code].info
	rooms_updated.emit(result)

func _exit_tree() -> void:
	stop_broadcasting()
	stop_listening()
