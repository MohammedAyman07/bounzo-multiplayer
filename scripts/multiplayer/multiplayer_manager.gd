extends Node

# ==============================================================================
# BOUNZO MULTIPLAYER MANAGER (Godot 4.7.1)
# Supports both:
# 1. Authoritative Dedicated Server Mode (connecting to remote VPS / headless server)
# 2. Local In-Process Host Mode (instant room hosting on localhost/LAN)
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")
const ServerRoomManager = preload("res://scripts/multiplayer/room_manager.gd")
const ServerMatchManager = preload("res://scripts/multiplayer/match_manager.gd")

signal connection_established
signal connection_failed(reason: String)
signal connection_lost(reason: String)
signal room_joined(room_data: Dictionary)
signal room_updated(room_data: Dictionary)
signal error_received(message: String)
signal countdown_started(info: Dictionary)
signal match_started(course_seed: int)
signal snapshot_received(snapshot: Array)
signal match_results_received(results: Array)
signal left_room

var server_host: String = "192.168.1.10"
var server_port: int = Protocol.DEFAULT_PORT
var connection_timeout: float = 12.0
var remote_config_url: String = ""

var peer: ENetMultiplayerPeer = null
var current_room: Dictionary = {}
var local_player_data: Dictionary = {}
var is_connected_to_server: bool = false
var is_host_mode: bool = false
var is_dedicated_server: bool = false
var last_snapshot: Array = []
var last_results: Array = []
var current_course_seed: int = 0
var current_difficulty: String = "NORMAL"

var is_server_authority: bool:
	get:
		if is_host_mode or is_dedicated_server:
			return true
		if multiplayer != null and multiplayer.has_multiplayer_peer():
			return multiplayer.is_server()
		return false

# Host mode & dedicated server managers
var room_manager: RefCounted = null
var match_manager: RefCounted = null
var _snapshot_timer: float = 0.0

var _is_connecting: bool = false
var _connect_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	if remote_config_url != "":
		fetch_remote_config()

var fallback_server_ip: String = "147.185.221.213"
var _tried_fallback: bool = false

func _load_config() -> void:
	# 1. Base config packaged with the build
	if FileAccess.file_exists("res://server_config.json"):
		var f = FileAccess.open("res://server_config.json", FileAccess.READ)
		if f:
			var text = f.get_as_text()
			f.close()
			var json = JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var cdefs = json.data.get("client_defaults", {})
				server_host = cdefs.get("default_server_host", "cairo-constantly.tun.ply.gg")
				fallback_server_ip = cdefs.get("fallback_server_ip", "147.185.221.213")
				server_port = int(cdefs.get("default_server_port", 42174))
				connection_timeout = float(cdefs.get("connection_timeout_seconds", 6.0))
				remote_config_url = cdefs.get("remote_config_url", "")

	# 2. Cached remote config if previously updated
	if FileAccess.file_exists("user://cached_server_config.json"):
		var f_cache = FileAccess.open("user://cached_server_config.json", FileAccess.READ)
		if f_cache:
			var text = f_cache.get_as_text()
			f_cache.close()
			var json = JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				if json.data.has("server_host"): server_host = str(json.data["server_host"])
				if json.data.has("server_port"): server_port = int(json.data["server_port"])

	# 3. User custom server override from settings (if explicitly changed in Advanced menu)
	# NOTE: Discard legacy hardcoded local IP (192.168.1.10) so existing installs migrate to public server
	if FileAccess.file_exists("user://multiplayer_settings.json"):
		var f_user = FileAccess.open("user://multiplayer_settings.json", FileAccess.READ)
		if f_user:
			var text = f_user.get_as_text()
			f_user.close()
			var json = JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var saved_host = str(json.data.get("server_host", ""))
				var saved_port = int(json.data.get("server_port", 0))
				if saved_host == "192.168.1.10":
					print("[MultiplayerManager] Discarding legacy 192.168.1.10 saved setting in favor of public server.")
					DirAccess.remove_absolute("user://multiplayer_settings.json")
				elif saved_host != "":
					server_host = saved_host
					if saved_port > 0:
						server_port = saved_port

func fetch_remote_config() -> void:
	if remote_config_url.strip_edges() == "":
		return
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var data = json.data
				var updated = false
				if data.has("server_host"):
					server_host = str(data["server_host"])
					updated = true
				elif data.has("default_server_host"):
					server_host = str(data["default_server_host"])
					updated = true
				if data.has("server_port"):
					server_port = int(data["server_port"])
					updated = true
				elif data.has("default_server_port"):
					server_port = int(data["default_server_port"])
					updated = true
				if updated:
					print("[MultiplayerManager] Updated server from remote config: %s:%d" % [server_host, server_port])
					_save_cached_config()
		http.queue_free()
	)
	http.request(remote_config_url)

func _save_cached_config() -> void:
	var f = FileAccess.open("user://cached_server_config.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"server_host": server_host, "server_port": server_port}))
		f.close()

func save_user_server_settings(host: String, port: int) -> void:
	server_host = host
	server_port = port
	var f = FileAccess.open("user://multiplayer_settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"server_host": host, "server_port": port}))
		f.close()


func _process(delta: float) -> void:
	if _is_connecting:
		_connect_timer += delta
		if _connect_timer >= connection_timeout:
			if not _tried_fallback and fallback_server_ip != "" and server_host != fallback_server_ip:
				print("[MultiplayerManager] Connection timed out to %s. Trying fallback IP %s:%d..." % [server_host, fallback_server_ip, server_port])
				_tried_fallback = true
				connect_to_server(fallback_server_ip, server_port)
				return
			_tried_fallback = false
			_is_connecting = false
			_disconnect_and_cleanup()
			connection_failed.emit("Connection timed out. Server unreachable.")

	# Server / Host mode match ticks
	if (is_host_mode or is_dedicated_server) and match_manager != null:
		var events: Array = match_manager.process_matches(delta)
		for ev in events:
			var ev_type: String = ev.event
			var code: String = ev.room_code
			if ev_type == "game_start":
				_host_notify_game_start(code, ev.room.match.seed)
			elif ev_type == "game_over":
				_host_notify_game_over(code, ev.results)

		_snapshot_timer += delta
		if _snapshot_timer >= Protocol.POSITION_UPDATE_INTERVAL:
			_snapshot_timer = 0.0
			_host_broadcast_snapshots()

## Start local hosting in-process (Host Mode)
func host_room(player_name: String, cosmetics: Dictionary) -> void:
	_disconnect_and_cleanup()

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(server_port, Protocol.MAX_PLAYERS_PER_ROOM)
	if err != OK:
		printerr("[MultiplayerManager] Failed to start host server on port %d: Error %d" % [server_port, err])
		error_received.emit("Failed to start host server on port %d (Error %d)" % [server_port, err])
		_disconnect_and_cleanup()
		return

	multiplayer.multiplayer_peer = peer
	is_host_mode = true
	is_connected_to_server = true

	room_manager = ServerRoomManager.new()
	match_manager = ServerMatchManager.new(room_manager)

	multiplayer.peer_connected.connect(_on_host_peer_connected)
	multiplayer.peer_disconnected.connect(_on_host_peer_disconnected)

	var res = room_manager.create_room(1, player_name, cosmetics)
	if not res.success:
		error_received.emit(res.error)
		_disconnect_and_cleanup()
		return

	current_room = ServerRoomManager.serialize_room_state(res.room)
	local_player_data = current_room.players[0]
	print("[MultiplayerManager] In-process host started! Room: %s" % current_room.code)
	room_joined.emit(current_room)

## Start dedicated server mode (headless or cloud container)
func start_dedicated_server(server_port_to_bind: int = Protocol.DEFAULT_PORT, max_clients_allowed: int = 100) -> void:
	_disconnect_and_cleanup()

	server_port = server_port_to_bind
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(server_port, max_clients_allowed)
	if err != OK:
		printerr("[MultiplayerManager] Failed to bind dedicated server on port %d: Error %d" % [server_port, err])
		return

	multiplayer.multiplayer_peer = peer
	is_dedicated_server = true
	is_connected_to_server = true

	room_manager = ServerRoomManager.new()
	match_manager = ServerMatchManager.new(room_manager)

	multiplayer.peer_connected.connect(_on_host_peer_connected)
	multiplayer.peer_disconnected.connect(_on_host_peer_disconnected)

	print("[MultiplayerManager] Dedicated Server active on port %d (Max clients: %d)" % [server_port, max_clients_allowed])

## Connect to dedicated server (Client Mode)
func connect_to_server(host: String = "", port: int = 0) -> void:
	if host != "":
		server_host = host
	if port > 0:
		server_port = port

	if is_connected_to_server and peer != null:
		connection_established.emit()
		return

	_disconnect_and_cleanup()

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(server_host, server_port)
	if err != OK:
		connection_failed.emit("Failed to initialize network client: Error %d" % err)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_is_connecting = true
	_connect_timer = 0.0
	print("[MultiplayerManager] Connecting to %s:%d..." % [server_host, server_port])

func disconnect_from_server() -> void:
	_disconnect_and_cleanup()
	connection_lost.emit("Disconnected by user")

func _disconnect_and_cleanup() -> void:
	_is_connecting = false
	is_connected_to_server = false
	is_host_mode = false
	is_dedicated_server = false
	current_room.clear()
	local_player_data.clear()
	room_manager = null
	match_manager = null

	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.peer_connected.is_connected(_on_host_peer_connected):
		multiplayer.peer_connected.disconnect(_on_host_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_host_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_host_peer_disconnected)

	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null

func _on_connected_to_server() -> void:
	_is_connecting = false
	_tried_fallback = false
	is_connected_to_server = true
	print("[MultiplayerManager] Successfully connected to server: %s:%d" % [server_host, server_port])
	connection_established.emit()

func _on_connection_failed() -> void:
	if not _tried_fallback and fallback_server_ip != "" and server_host != fallback_server_ip:
		print("[MultiplayerManager] Connection failed to %s. Trying fallback IP %s:%d..." % [server_host, fallback_server_ip, server_port])
		_tried_fallback = true
		connect_to_server(fallback_server_ip, server_port)
		return

	_tried_fallback = false
	_is_connecting = false
	is_connected_to_server = false
	print("[MultiplayerManager] Connection failed completely.")
	connection_failed.emit("Could not establish connection with server.")

func _on_server_disconnected() -> void:
	_is_connecting = false
	is_connected_to_server = false
	print("[MultiplayerManager] Server disconnected.")
	connection_lost.emit("Connection lost: Server closed or timed out.")

# ==============================================================================
# ACTIONS (CLIENT & HOST METHODS)
# ==============================================================================

func create_room(player_name: String, cosmetics: Dictionary) -> void:
	# If server host is 127.0.0.1 or localhost, host directly in-process!
	if server_host in ["127.0.0.1", "localhost", ""]:
		host_room(player_name, cosmetics)
		return

	if not is_connected_to_server:
		error_received.emit("Not connected to multiplayer server")
		return
	rpc_id(1, "rpc_request_create_room", player_name, cosmetics)

func join_room(code: String, player_name: String, cosmetics: Dictionary) -> void:
	if is_host_mode:
		error_received.emit("Cannot join while hosting")
		return
	if not is_connected_to_server:
		error_received.emit("Not connected to multiplayer server")
		return
	rpc_id(1, "rpc_request_join_room", code.strip_edges().to_upper(), player_name, cosmetics)

func set_ready(is_ready: bool) -> void:
	if is_host_mode:
		# Host is always ready
		return
	if not is_connected_to_server: return
	rpc_id(1, "rpc_request_set_ready", is_ready)

func set_target_score(target_score: int) -> void:
	if is_host_mode:
		var code = current_room.get("code", "")
		var res = room_manager.set_room_target_score(code, 1, target_score)
		if res.success:
			_host_broadcast_room_update(code)
		return
	if not is_connected_to_server: return
	rpc_id(1, "rpc_request_set_target_score", target_score)

func set_difficulty(difficulty: String) -> void:
	current_difficulty = difficulty.to_upper().strip_edges()
	if is_host_mode:
		var code = current_room.get("code", "")
		var res = room_manager.set_room_difficulty(code, 1, current_difficulty)
		if res.success:
			_host_broadcast_room_update(code)
		return
	if not is_connected_to_server: return
	rpc_id(1, "rpc_request_set_difficulty", current_difficulty)

func start_match() -> void:
	if is_host_mode:
		var code = current_room.get("code", "")
		var start_res = match_manager.start_match_countdown(code)
		if not start_res.success:
			error_received.emit(start_res.error)
			return
		_host_broadcast_countdown(code, start_res)
		return

	if not is_connected_to_server: return
	rpc_id(1, "rpc_request_start_match")

func leave_current_room() -> void:
	if is_host_mode:
		_disconnect_and_cleanup()
		left_room.emit()
		return
	if not is_connected_to_server: return
	rpc_id(1, "rpc_request_leave_room")

func request_rematch() -> void:
	if is_host_mode:
		var code = current_room.get("code", "")
		var res = match_manager.prepare_rematch(code)
		if res.success:
			_host_broadcast_room_update(code)
		return
	if not is_connected_to_server: return
	rpc_id(1, "rpc_request_rematch")

func send_position_update(payload: Dictionary) -> void:
	if is_host_mode:
		match_manager.receive_player_update(1, payload)
		return
	if not is_connected_to_server: return
	rpc_id(1, "rpc_send_player_update", payload)

# ==============================================================================
# HOST MODE EVENT HANDLERS & BROADCASTS
# ==============================================================================

func _on_host_peer_connected(id: int) -> void:
	print("[HostMode] Peer %d connected" % id)

func _on_host_peer_disconnected(id: int) -> void:
	print("[HostMode] Peer %d disconnected" % id)
	if match_manager: match_manager.clear_peer(id)
	if room_manager:
		var leave_res = room_manager.leave_room(id)
		if leave_res.success and not leave_res.room_deleted:
			_host_broadcast_room_update(leave_res.code)

func _host_broadcast_room_update(room_code: String) -> void:
	var room: Dictionary = room_manager.get_room(room_code)
	if room.is_empty(): return
	var state = ServerRoomManager.serialize_room_state(room)
	if is_host_mode:
		current_room = state
		room_updated.emit(state)
	for pid in room.players:
		if not is_host_mode or pid != 1:
			rpc_id(pid, "client_sync_room_state", state)

func _host_broadcast_countdown(room_code: String, start_res: Dictionary) -> void:
	current_course_seed = int(start_res.seed)
	if start_res.has("difficulty"):
		current_difficulty = str(start_res["difficulty"])
	if is_host_mode:
		countdown_started.emit(start_res)
	var room: Dictionary = room_manager.get_room(room_code)
	for pid in room.players:
		if not is_host_mode or pid != 1:
			rpc_id(pid, "client_match_countdown_started", start_res)

func _host_broadcast_snapshots() -> void:
	for code in room_manager.rooms.keys():
		var room: Dictionary = room_manager.rooms[code]
		if room.state == Protocol.RoomState.IN_GAME:
			var snap: Array = match_manager.get_room_snapshot(code)
			if is_host_mode:
				last_snapshot = snap
				snapshot_received.emit(snap)
			for pid in room.players:
				if not is_host_mode or pid != 1:
					rpc_id(pid, "client_receive_snapshot", snap)

func _host_notify_game_start(room_code: String, course_seed: int) -> void:
	current_course_seed = course_seed
	if is_host_mode:
		match_started.emit(course_seed)
	var room: Dictionary = room_manager.get_room(room_code)
	for pid in room.players:
		if not is_host_mode or pid != 1:
			rpc_id(pid, "client_match_started", course_seed)

func _host_notify_game_over(room_code: String, results: Array) -> void:
	if is_host_mode:
		last_results = results
		match_results_received.emit(results)
	var room: Dictionary = room_manager.get_room(room_code)
	for pid in room.players:
		if not is_host_mode or pid != 1:
			rpc_id(pid, "client_match_results", results)

# ==============================================================================
# INCOMING RPCs (FOR GUEST CLIENTS CONNECTED TO HOST OR DEDICATED SERVER)
# ==============================================================================

@rpc("authority", "call_remote", "reliable")
func client_receive_error(err_msg: String) -> void:
	print("[MultiplayerManager] Server Error: %s" % err_msg)
	error_received.emit(err_msg)

@rpc("authority", "call_remote", "reliable")
func client_room_joined(room_data: Dictionary) -> void:
	current_room = room_data
	var local_id = multiplayer.get_unique_id()
	for p in room_data.players:
		if p.peer_id == local_id:
			local_player_data = p
			break
	print("[MultiplayerManager] Joined room %s" % room_data.code)
	room_joined.emit(room_data)

@rpc("authority", "call_remote", "reliable")
func client_sync_room_state(room_data: Dictionary) -> void:
	current_room = room_data
	if room_data.has("difficulty"):
		current_difficulty = str(room_data["difficulty"])
	var local_id = multiplayer.get_unique_id()
	for p in room_data.players:
		if p.peer_id == local_id:
			local_player_data = p
			break
	room_updated.emit(room_data)

@rpc("authority", "call_remote", "reliable")
func client_match_countdown_started(info: Dictionary) -> void:
	current_course_seed = int(info.get("seed", 0))
	if info.has("difficulty"):
		current_difficulty = str(info["difficulty"])
	print("[MultiplayerManager] Countdown started with seed %d (Diff: %s)" % [current_course_seed, current_difficulty])
	countdown_started.emit(info)

@rpc("authority", "call_remote", "reliable")
func client_match_started(course_seed: int) -> void:
	current_course_seed = course_seed
	print("[MultiplayerManager] Match started! Course seed: %d" % course_seed)
	match_started.emit(course_seed)

@rpc("authority", "call_remote", "reliable")
func client_left_room() -> void:
	current_room.clear()
	local_player_data.clear()
	left_room.emit()

@rpc("authority", "call_remote", "unreliable")
func client_receive_snapshot(snapshot: Array) -> void:
	last_snapshot = snapshot
	snapshot_received.emit(snapshot)

@rpc("authority", "call_remote", "reliable")
func client_match_results(results: Array) -> void:
	last_results = results
	print("[MultiplayerManager] Match results received.")
	match_results_received.emit(results)

# ==============================================================================
# INCOMING RPCs (GUEST -> HOST OR DEDICATED SERVER)
# ==============================================================================

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_create_room(player_name: String, cosmetics: Dictionary) -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var res = room_manager.create_room(sender_id, player_name, cosmetics)
	if not res.success:
		rpc_id(sender_id, "client_receive_error", res.error)
		return
	var room_state = ServerRoomManager.serialize_room_state(res.room)
	rpc_id(sender_id, "client_room_joined", room_state)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_join_room(code: String, player_name: String, cosmetics: Dictionary) -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var res = room_manager.join_room(sender_id, code, player_name, cosmetics)
	if not res.success:
		rpc_id(sender_id, "client_receive_error", res.error)
		return
	var room_state = ServerRoomManager.serialize_room_state(res.room)
	rpc_id(sender_id, "client_room_joined", room_state)
	_host_broadcast_room_update(res.code)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_set_ready(is_ready: bool) -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var res = room_manager.set_player_ready(sender_id, is_ready)
	if res.success:
		_host_broadcast_room_update(res.code)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_set_target_score(target_score: int) -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var room: Dictionary = room_manager.get_room_by_peer(sender_id)
	if room.is_empty(): return
	var res = room_manager.set_room_target_score(room.code, sender_id, target_score)
	if res.success:
		_host_broadcast_room_update(room.code)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_set_difficulty(difficulty: String) -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var room: Dictionary = room_manager.get_room_by_peer(sender_id)
	if room.is_empty(): return
	var res = room_manager.set_room_difficulty(room.code, sender_id, difficulty)
	if res.success:
		_host_broadcast_room_update(room.code)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_start_match() -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var room: Dictionary = room_manager.get_room_by_peer(sender_id)
	if room.is_empty():
		rpc_id(sender_id, "client_receive_error", "Not in a room")
		return
	if room.host_id != sender_id:
		rpc_id(sender_id, "client_receive_error", "Only room host can start the match")
		return
	var start_res = match_manager.start_match_countdown(room.code)
	if not start_res.success:
		rpc_id(sender_id, "client_receive_error", start_res.error)
		return
	_host_broadcast_countdown(room.code, start_res)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_leave_room() -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var res = room_manager.leave_room(sender_id)
	rpc_id(sender_id, "client_left_room")
	if res.success and not res.room_deleted:
		_host_broadcast_room_update(res.code)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_rematch() -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	var room: Dictionary = room_manager.get_room_by_peer(sender_id)
	if room.is_empty() or room.host_id != sender_id: return
	var res = match_manager.prepare_rematch(room.code)
	if res.success:
		_host_broadcast_room_update(room.code)

@rpc("any_peer", "call_remote", "unreliable")
func rpc_send_player_update(payload: Dictionary) -> void:
	if not is_server_authority: return
	var sender_id = multiplayer.get_remote_sender_id()
	match_manager.receive_player_update(sender_id, payload)
