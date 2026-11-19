class_name MultiplayerLobbyUI
extends Control

# ==============================================================================
# BOUNZO MULTIPLAYER LOBBY UI (Godot 4.7.1)
# Dual Hosting (Phone LAN & PC/Cloud Server), LAN Auto-Discovery, Room Codes,
# and 4-Player Ready-Up Lobby.
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")
const BeaconClass = preload("res://scripts/multiplayer/lan_beacon.gd")

# Autoload accessors (safe against uninitialized test environments)
var _mp_mgr: Node:
	get: return get_node_or_null("/root/MultiplayerManager")
var _save_mgr: Node:
	get: return get_node_or_null("/root/SaveManager")
var _ad_mgr: Node:
	get: return get_node_or_null("/root/AdManager")
var _ui_theme: Node:
	get: return get_node_or_null("/root/UITheme")

# Panels
@onready var entry_panel: Control = $SafeMargin/VBox/EntryPanel
@onready var room_panel: Control = $SafeMargin/VBox/RoomPanel
@onready var status_lbl: Label = $SafeMargin/VBox/StatusLabel
@onready var device_ip_lbl: Label = $SafeMargin/VBox/DeviceIpLabel

# LAN Discovery Card
@onready var lan_card: PanelContainer = $SafeMargin/VBox/LanCard
@onready var lan_info_lbl: Label = $SafeMargin/VBox/LanCard/LanHBox/LanInfoLabel
@onready var lan_join_btn: Button = $SafeMargin/VBox/LanCard/LanHBox/LanJoinBtn

# Entry Controls
@onready var name_input: LineEdit = $SafeMargin/VBox/EntryPanel/NameInput
@onready var create_btn: Button = $SafeMargin/VBox/EntryPanel/CreateRoomBtn
@onready var join_btn: Button = $SafeMargin/VBox/EntryPanel/JoinRoomBtn
@onready var join_box: Control = $SafeMargin/VBox/EntryPanel/JoinBox
@onready var code_input: LineEdit = $SafeMargin/VBox/EntryPanel/JoinBox/CodeInput
@onready var join_submit_btn: Button = $SafeMargin/VBox/EntryPanel/JoinBox/JoinSubmitBtn
@onready var host_phone_btn: Button = $SafeMargin/VBox/EntryPanel/HostPhoneBtn
@onready var server_box: Control = $SafeMargin/VBox/EntryPanel/ServerBox
@onready var set_hotspot_ip_btn: Button = $SafeMargin/VBox/EntryPanel/ServerBox/ServerHeaderHBox/SetHotspotIpBtn
@onready var set_pc_ip_btn: Button = $SafeMargin/VBox/EntryPanel/ServerBox/ServerHeaderHBox/SetPcIpBtn
@onready var server_input: LineEdit = $SafeMargin/VBox/EntryPanel/ServerBox/ServerInput
@onready var advanced_btn: Button = $SafeMargin/VBox/EntryPanel/AdvancedBtn
@onready var back_btn: Button = $SafeMargin/VBox/EntryPanel/BackBtn

# Room Controls
@onready var room_code_lbl: Label = $SafeMargin/VBox/RoomPanel/Header/RoomCodeLabel
@onready var copy_code_btn: Button = $SafeMargin/VBox/RoomPanel/Header/CopyCodeBtn
@onready var host_addr_lbl: Label = $SafeMargin/VBox/RoomPanel/HostAddrHBox/HostAddrLabel
@onready var copy_host_addr_btn: Button = $SafeMargin/VBox/RoomPanel/HostAddrHBox/CopyHostAddrBtn
@onready var broadcast_status_lbl: Label = $SafeMargin/VBox/RoomPanel/BroadcastStatusLabel
@onready var target_score_container: HBoxContainer = $SafeMargin/VBox/RoomPanel/TargetScoreContainer
@onready var target_score_lbl: Label = $SafeMargin/VBox/RoomPanel/TargetScoreContainer/TargetScoreLabel
@onready var change_score_btn: Button = $SafeMargin/VBox/RoomPanel/TargetScoreContainer/ChangeScoreBtn
@onready var slots_container: VBoxContainer = $SafeMargin/VBox/RoomPanel/SlotsContainer
@onready var start_match_btn: Button = $SafeMargin/VBox/RoomPanel/Actions/StartMatchBtn
@onready var ready_btn: Button = $SafeMargin/VBox/RoomPanel/Actions/ReadyBtn
@onready var leave_room_btn: Button = $SafeMargin/VBox/RoomPanel/Actions/LeaveRoomBtn

var minus_score_btn: Button = null
var plus_score_btn: Button = null
var diff_container: HBoxContainer = null
var diff_lbl: Label = null
var change_diff_btn: Button = null

const TARGET_SCORE_OPTIONS: Array[int] = [1000, 2000, 3000, 5000, 10000, 25000, 50000, 100000]
const DIFFICULTY_OPTIONS: Array[String] = ["EASY", "NORMAL", "HARD", "INSANE"]

var beacon: Node = null
var latest_discovered_room: Dictionary = {}
var is_local_ready: bool = false
var is_host: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	if _ad_mgr != null and _ad_mgr.has_method("hide_banner"):
		_ad_mgr.hide_banner()
	_apply_styling()

	# Initialize LAN discovery beacon
	beacon = BeaconClass.new()
	add_child(beacon)
	beacon.rooms_updated.connect(_on_lan_rooms_updated)
	beacon.start_listening()

	# Populate defaults & detect Hotspot
	var local_ip = Protocol.get_local_ip()
	if Protocol.is_hotspot_network():
		if local_ip == "192.168.43.1":
			device_ip_lbl.text = "HOTSPOT HOST: 192.168.43.1"
			status_lbl.text = "Hotspot Host detected! Tap Advanced to host LAN"
		else:
			device_ip_lbl.text = "HOTSPOT CLIENT: %s" % local_ip
			status_lbl.text = "Hotspot connected! Enter Room Code to join"
	else:
		device_ip_lbl.text = "YOUR DEVICE IP: %s" % local_ip
		status_lbl.text = "Create a room or enter a code to join!"

	var default_name = "Player_%d" % (randi() % 900 + 100)
	if _save_mgr != null and _save_mgr.get("data") != null and _save_mgr.data.has("selected_ball"):
		default_name = "Bounzo_%s" % str(_save_mgr.data.get("selected_ball", "ball")).capitalize()
	name_input.text = default_name

	if Protocol.is_hotspot_network() and local_ip != "192.168.43.1":
		server_input.text = "192.168.43.1:7777"
	else:
		var s_host = _mp_mgr.server_host if _mp_mgr != null else "cairo-constantly.tun.ply.gg"
		var s_port = _mp_mgr.server_port if _mp_mgr != null else 42174
		server_input.text = "%s:%d" % [s_host, s_port]

	# Connect signals
	create_btn.pressed.connect(_on_create_server_pressed)
	join_btn.pressed.connect(_on_join_mode_pressed)
	join_submit_btn.pressed.connect(_on_join_submit_pressed)
	advanced_btn.pressed.connect(_on_advanced_pressed)
	host_phone_btn.pressed.connect(_on_host_phone_pressed)
	set_hotspot_ip_btn.pressed.connect(_on_set_hotspot_ip_pressed)
	set_pc_ip_btn.pressed.connect(_on_set_pc_ip_pressed)
	lan_join_btn.pressed.connect(_on_lan_join_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	copy_code_btn.pressed.connect(_on_copy_code_pressed)
	copy_host_addr_btn.pressed.connect(_on_copy_host_addr_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	start_match_btn.pressed.connect(_on_start_match_pressed)
	leave_room_btn.pressed.connect(_on_leave_room_pressed)
	change_score_btn.pressed.connect(_on_change_target_score_pressed)

	# Quick score -1K / +1K buttons
	minus_score_btn = Button.new()
	minus_score_btn.text = "-1K"
	minus_score_btn.custom_minimum_size = Vector2(48, 36)
	target_score_container.add_child(minus_score_btn)
	minus_score_btn.pressed.connect(_on_minus_score_pressed)

	plus_score_btn = Button.new()
	plus_score_btn.text = "+1K"
	plus_score_btn.custom_minimum_size = Vector2(48, 36)
	target_score_container.add_child(plus_score_btn)
	plus_score_btn.pressed.connect(_on_plus_score_pressed)

	# Difficulty Selector Row
	diff_container = HBoxContainer.new()
	diff_container.add_theme_constant_override("separation", 8)
	var room_panel_vbox = $SafeMargin/VBox/RoomPanel
	var target_idx = target_score_container.get_index()
	room_panel_vbox.add_child(diff_container)
	room_panel_vbox.move_child(diff_container, target_idx + 1)

	diff_lbl = Label.new()
	diff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_lbl.text = "🟡 DIFFICULTY: NORMAL"
	diff_lbl.label_settings = target_score_lbl.label_settings
	diff_container.add_child(diff_lbl)

	change_diff_btn = Button.new()
	change_diff_btn.text = "CHANGE"
	change_diff_btn.custom_minimum_size = Vector2(100, 36)
	diff_container.add_child(change_diff_btn)
	change_diff_btn.pressed.connect(_on_change_difficulty_pressed)

	if _mp_mgr != null:
		_mp_mgr.connection_established.connect(_on_connected)
		_mp_mgr.connection_failed.connect(_on_connection_error)
		_mp_mgr.connection_lost.connect(_on_connection_error)
		_mp_mgr.room_joined.connect(_on_room_joined)
		_mp_mgr.room_updated.connect(_on_room_updated)
		_mp_mgr.error_received.connect(_on_server_error)
		_mp_mgr.countdown_started.connect(_on_countdown_started)
		_mp_mgr.match_started.connect(_on_match_started)
		_mp_mgr.left_room.connect(_on_left_room)

	# Initial visibility
	entry_panel.show()
	room_panel.hide()
	join_box.hide()
	lan_card.hide()
	server_box.hide()
	host_phone_btn.hide()
	device_ip_lbl.hide()

func _apply_styling() -> void:
	if _ui_theme != null:
		if _ui_theme.has_method("btn_primary"):
			create_btn.add_theme_stylebox_override("normal", _ui_theme.btn_primary())
			start_match_btn.add_theme_stylebox_override("normal", _ui_theme.btn_primary())
		if _ui_theme.has_method("btn_secondary"):
			join_btn.add_theme_stylebox_override("normal", _ui_theme.btn_secondary())
			host_phone_btn.add_theme_stylebox_override("normal", _ui_theme.btn_secondary())

func _get_current_cosmetics() -> Dictionary:
	var ball = "basic"
	var trail = "basic"
	if _save_mgr != null and _save_mgr.get("data") != null:
		ball = _save_mgr.data.get("selected_ball", "basic")
		trail = _save_mgr.data.get("selected_trail", "basic")
	return { "ball": ball, "trail": trail }

func _parse_server_address() -> void:
	var text = server_input.text.strip_edges()
	var host = text
	var port = 42174
	if ":" in text:
		var parts = text.split(":")
		host = parts[0].strip_edges()
		port = int(parts[1].strip_edges())

	if _mp_mgr != null:
		_mp_mgr.server_host = host
		_mp_mgr.server_port = port

func _on_advanced_pressed() -> void:
	var show_adv = not server_box.visible
	server_box.visible = show_adv
	host_phone_btn.visible = show_adv
	device_ip_lbl.visible = show_adv
	advanced_btn.text = "⚙️ HIDE ADVANCED" if show_adv else "⚙️ ADVANCED / LOCAL NETWORK"

func _on_set_hotspot_ip_pressed() -> void:
	server_input.text = "192.168.43.1:7777"
	_parse_server_address()
	if _mp_mgr != null and _mp_mgr.has_method("save_user_server_settings"):
		_mp_mgr.save_user_server_settings("192.168.43.1", 7777)
	status_lbl.text = "Configured for Hotspot Host: 192.168.43.1:7777"

func _on_set_pc_ip_pressed() -> void:
	server_input.text = "cairo-constantly.tun.ply.gg:42174"
	_parse_server_address()
	if _mp_mgr != null and _mp_mgr.has_method("save_user_server_settings"):
		_mp_mgr.save_user_server_settings("cairo-constantly.tun.ply.gg", 42174)
	status_lbl.text = "Configured for Public Server: cairo-constantly.tun.ply.gg:42174"

## Option 1: Host directly on this mobile phone (No PC needed)
func _on_host_phone_pressed() -> void:
	status_lbl.text = "Hosting room on this device..."
	if _mp_mgr != null:
		_mp_mgr.host_room(name_input.text, _get_current_cosmetics())

## Option 2: Create room on PC / Remote Dedicated Server
func _on_create_server_pressed() -> void:
	_parse_server_address()
	var target_host = _mp_mgr.server_host if _mp_mgr != null else "cairo-constantly.tun.ply.gg"
	var target_port = _mp_mgr.server_port if _mp_mgr != null else 42174
	status_lbl.text = "Connecting to server %s:%d..." % [target_host, target_port]
	_ensure_connected(func():
		if _mp_mgr != null:
			_mp_mgr.create_room(name_input.text, _get_current_cosmetics())
	)

func _on_join_mode_pressed() -> void:
	join_box.visible = not join_box.visible
	if join_box.visible:
		code_input.grab_focus()

func _on_join_submit_pressed() -> void:
	var code = code_input.text.strip_edges().to_upper()
	if code.length() != Protocol.ROOM_CODE_LENGTH:
		status_lbl.text = "Room code must be %d characters" % Protocol.ROOM_CODE_LENGTH
		return

	_parse_server_address()
	_ensure_connected(func():
		status_lbl.text = "Joining room %s..." % code
		if _mp_mgr != null:
			_mp_mgr.join_room(code, name_input.text, _get_current_cosmetics())
	)

## LAN Auto-Discovery handlers
func _on_lan_rooms_updated(rooms: Dictionary) -> void:
	if rooms.is_empty():
		lan_card.hide()
		latest_discovered_room.clear()
		return

	# Show first discovered room
	var first_code = rooms.keys()[0]
	latest_discovered_room = rooms[first_code]
	var host_name = latest_discovered_room.get("host", "Player")
	var count = int(latest_discovered_room.get("count", 1))

	lan_info_lbl.text = "🟢 LAN ROOM: [%s] Host: %s (%d/4)" % [first_code, host_name, count]
	lan_card.show()

func _on_lan_join_pressed() -> void:
	if latest_discovered_room.is_empty(): return
	var code: String = latest_discovered_room.get("code", "")
	var ip: String = latest_discovered_room.get("ip", "")
	var port: int = int(latest_discovered_room.get("port", Protocol.DEFAULT_PORT))

	if _mp_mgr != null:
		_mp_mgr.server_host = ip
		_mp_mgr.server_port = port
	server_input.text = "%s:%d" % [ip, port]

	status_lbl.text = "Auto-joining LAN host %s:%d [%s]..." % [ip, port, code]
	_ensure_connected(func():
		if _mp_mgr != null:
			_mp_mgr.join_room(code, name_input.text, _get_current_cosmetics())
	)

func _ensure_connected(callback: Callable) -> void:
	if _mp_mgr == null:
		callback.call()
		return

	if _mp_mgr.is_connected_to_server:
		callback.call()
		return

	status_lbl.text = "Connecting to %s:%d..." % [_mp_mgr.server_host, _mp_mgr.server_port]

	var on_conn: Callable
	var on_fail: Callable

	on_conn = func():
		if _mp_mgr.connection_established.is_connected(on_conn):
			_mp_mgr.connection_established.disconnect(on_conn)
		if _mp_mgr.connection_failed.is_connected(on_fail):
			_mp_mgr.connection_failed.disconnect(on_fail)
		callback.call()

	on_fail = func(reason: String):
		if _mp_mgr.connection_established.is_connected(on_conn):
			_mp_mgr.connection_established.disconnect(on_conn)
		if _mp_mgr.connection_failed.is_connected(on_fail):
			_mp_mgr.connection_failed.disconnect(on_fail)
		status_lbl.text = "Server offline (%s:%d).\nTap below to host directly on this phone!" % [_mp_mgr.server_host, _mp_mgr.server_port]
		host_phone_btn.visible = true

	_mp_mgr.connection_established.connect(on_conn)
	_mp_mgr.connection_failed.connect(on_fail)
	_mp_mgr.connect_to_server()

func _on_back_pressed() -> void:
	if _mp_mgr != null:
		_mp_mgr.disconnect_from_server()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_copy_code_pressed() -> void:
	if _mp_mgr == null: return
	var room = _mp_mgr.current_room
	var code = room.get("code", "")
	if code != "":
		DisplayServer.clipboard_set(code)
		status_lbl.text = "Room code %s copied!" % code

func _on_copy_host_addr_pressed() -> void:
	var text = host_addr_lbl.text.replace("HOST: ", "").replace("CONNECTED TO: ", "")
	DisplayServer.clipboard_set(text)
	status_lbl.text = "Address %s copied!" % text

func _on_change_target_score_pressed() -> void:
	if not is_host or _mp_mgr == null: return
	var cur_score = int(_mp_mgr.current_room.get("target_score", 2000))
	var idx = TARGET_SCORE_OPTIONS.find(cur_score)
	if idx == -1: idx = 1
	var next_idx = (idx + 1) % TARGET_SCORE_OPTIONS.size()
	var next_score = TARGET_SCORE_OPTIONS[next_idx]
	_mp_mgr.set_target_score(next_score)

func _on_minus_score_pressed() -> void:
	if not is_host or _mp_mgr == null: return
	var cur_score = int(_mp_mgr.current_room.get("target_score", 2000))
	var next_score = clamp(cur_score - 1000, 1000, 100000)
	_mp_mgr.set_target_score(next_score)

func _on_plus_score_pressed() -> void:
	if not is_host or _mp_mgr == null: return
	var cur_score = int(_mp_mgr.current_room.get("target_score", 2000))
	var next_score = clamp(cur_score + 1000, 1000, 100000)
	_mp_mgr.set_target_score(next_score)

func _on_change_difficulty_pressed() -> void:
	if not is_host or _mp_mgr == null: return
	var cur_diff = str(_mp_mgr.current_room.get("difficulty", "NORMAL")).to_upper()
	var idx = DIFFICULTY_OPTIONS.find(cur_diff)
	if idx == -1: idx = 1
	var next_idx = (idx + 1) % DIFFICULTY_OPTIONS.size()
	var next_diff = DIFFICULTY_OPTIONS[next_idx]
	_mp_mgr.set_difficulty(next_diff)

func _on_ready_pressed() -> void:
	is_local_ready = not is_local_ready
	ready_btn.text = "READY!" if is_local_ready else "NOT READY"
	if _mp_mgr != null:
		_mp_mgr.set_ready(is_local_ready)

func _on_start_match_pressed() -> void:
	if is_host and _mp_mgr != null:
		status_lbl.text = "Starting match countdown..."
		_mp_mgr.start_match()

func _on_leave_room_pressed() -> void:
	if _mp_mgr != null:
		_mp_mgr.leave_current_room()

func _on_connected() -> void:
	status_lbl.text = "Connected to server."

func _on_connection_error(reason: String) -> void:
	status_lbl.text = "Connection lost or timed out.\nTap [⚙️ ADVANCED] to check server address or host on Hotspot."
	entry_panel.show()
	room_panel.hide()

func _on_server_error(msg: String) -> void:
	status_lbl.text = "Error: %s" % msg

func _on_room_joined(room_data: Dictionary) -> void:
	entry_panel.hide()
	room_panel.show()
	status_lbl.text = ""
	_update_room_ui(room_data)

	if is_host and beacon != null:
		var code: String = room_data.get("code", "")
		var port: int = _mp_mgr.server_port if _mp_mgr != null else Protocol.DEFAULT_PORT
		beacon.start_broadcasting(code, name_input.text, port, room_data.get("players", []).size())
		broadcast_status_lbl.show()
	else:
		broadcast_status_lbl.hide()

func _on_room_updated(room_data: Dictionary) -> void:
	_update_room_ui(room_data)
	if is_host and beacon != null:
		beacon.update_player_count(room_data.get("players", []).size())

func _update_room_ui(room_data: Dictionary) -> void:
	var room_code = str(room_data.get("code", "-----"))
	room_code_lbl.text = "CODE: %s" % room_code

	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var is_host_mode = _mp_mgr.is_host_mode if _mp_mgr != null else false
	is_host = (int(room_data.get("host_id", 0)) == local_id or is_host_mode)

	var s_port = _mp_mgr.server_port if _mp_mgr != null else Protocol.DEFAULT_PORT
	if is_host:
		var my_ip = Protocol.get_local_ip()
		host_addr_lbl.text = "HOST: %s:%d" % [my_ip, s_port]
		start_match_btn.show()
		ready_btn.hide()
		var p_count = int(room_data.get("player_count", 1))
		start_match_btn.disabled = (p_count < Protocol.MIN_PLAYERS_TO_START)
		if p_count < Protocol.MIN_PLAYERS_TO_START:
			start_match_btn.text = "WAITING FOR PLAYERS (1/4)"
		else:
			var all_ready: bool = true
			for p in room_data.players:
				if not p.ready:
					all_ready = false
					break
			start_match_btn.disabled = not all_ready
			start_match_btn.text = "START MATCH" if all_ready else "WAITING FOR READY"
	else:
		var s_host = _mp_mgr.server_host if _mp_mgr != null else "192.168.1.10"
		host_addr_lbl.text = "CONNECTED TO: %s:%d" % [s_host, s_port]
		start_match_btn.hide()
		ready_btn.show()

	# Update Target Score display
	var target_score = int(room_data.get("target_score", 2000))
	if target_score == 0:
		target_score_lbl.text = "🎯 GOAL: SURVIVAL (LAST MAN STANDING)"
	else:
		target_score_lbl.text = "🎯 GOAL: %d PTS (MIN 1K - MAX 100K)" % target_score

	change_score_btn.visible = is_host
	if minus_score_btn != null: minus_score_btn.visible = is_host
	if plus_score_btn != null: plus_score_btn.visible = is_host

	# Update Difficulty display
	var cur_diff = str(room_data.get("difficulty", "NORMAL")).to_upper()
	var diff_emoji = "🟢" if cur_diff == "EASY" else ("🟡" if cur_diff == "NORMAL" else ("🔴" if cur_diff == "HARD" else "🔥"))
	if diff_lbl != null:
		diff_lbl.text = "%s DIFFICULTY: %s" % [diff_emoji, cur_diff]
	if change_diff_btn != null:
		change_diff_btn.visible = is_host

	# Rebuild player slot list
	for child in slots_container.get_children():
		child.queue_free()

	var players_list = room_data.get("players", [])
	for s_idx in range(Protocol.MAX_PLAYERS_PER_ROOM):
		var p_found = null
		for p in players_list:
			if int(p.slot) == s_idx:
				p_found = p
				break

		var slot_card = PanelContainer.new()
		slot_card.custom_minimum_size = Vector2(0, 50)
		var slot_color = Protocol.SLOT_COLORS[s_idx]

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var indicator = ColorRect.new()
		indicator.custom_minimum_size = Vector2(10, 50)
		indicator.color = slot_color if p_found != null else Color(0.2, 0.2, 0.25, 0.5)
		hbox.add_child(indicator)

		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if p_found != null:
			var is_p_host = (p_found.peer_id == 1)
			var suffix = " (HOST)" if is_p_host else ""
			name_lbl.text = "%s%s" % [p_found.name, suffix]
			name_lbl.modulate = Color.WHITE
		else:
			name_lbl.text = "[ SLOT %d: WAITING... ]" % (s_idx + 1)
			name_lbl.modulate = Color(0.5, 0.5, 0.55, 0.7)
		hbox.add_child(name_lbl)

		var status_badge = Label.new()
		if p_found != null:
			if p_found.peer_id == 1:
				status_badge.text = "HOST"
				status_badge.modulate = Color(0.098, 0.851, 1, 1)
			else:
				status_badge.text = "READY" if p_found.ready else "WAITING"
				status_badge.modulate = Color(0.224, 1, 0.533, 1) if p_found.ready else Color(1, 0.824, 0.122, 1)
		else:
			status_badge.text = "EMPTY"
			status_badge.modulate = Color(0.4, 0.4, 0.45, 0.6)
		hbox.add_child(status_badge)

		slot_card.add_child(hbox)
		slots_container.add_child(slot_card)

func _on_countdown_started(info: Dictionary) -> void:
	status_lbl.text = "MATCH STARTING IN %d SECONDS..." % int(info.get("duration", 3.0))

func _on_match_started(seed: int) -> void:
	if beacon != null:
		beacon.stop_broadcasting()
		beacon.stop_listening()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_game.tscn")

func _on_left_room() -> void:
	if beacon != null:
		beacon.stop_broadcasting()
		beacon.start_listening()
	entry_panel.show()
	room_panel.hide()
	is_local_ready = false
	ready_btn.text = "NOT READY"
	status_lbl.text = "Left room."
