class_name DedicatedServer
extends Node

# ==============================================================================
# BOUNZO DEDICATED HEADLESS SERVER LAUNCHER (Godot 4.7.1)
# Launches authoritative server on MultiplayerManager singleton
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")

var port: int = Protocol.DEFAULT_PORT
var max_clients: int = 100

var peer: ENetMultiplayerPeer:
	get:
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		return mp_mgr.peer if mp_mgr else null

var room_manager: RefCounted:
	get:
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		return mp_mgr.room_manager if mp_mgr else null

var match_manager: RefCounted:
	get:
		var mp_mgr = get_node_or_null("/root/MultiplayerManager")
		return mp_mgr.match_manager if mp_mgr else null

func _ready() -> void:
	print("==================================================")
	print(" BOUNZO ONLINE DEDICATED SERVER (Godot 4.7.1)")
	print("==================================================")

	_parse_cmdline_args()
	_initialize_server()

func _parse_cmdline_args() -> void:
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	for i in range(args.size()):
		var arg = args[i]
		if arg == "--port" and i + 1 < args.size():
			port = int(args[i + 1])
		elif arg == "--max-clients" and i + 1 < args.size():
			max_clients = int(args[i + 1])

	if OS.has_environment("BOUNZO_SERVER_PORT"):
		port = int(OS.get_environment("BOUNZO_SERVER_PORT"))

func _initialize_server() -> void:
	var mp_mgr = get_node_or_null("/root/MultiplayerManager")
	if mp_mgr != null and mp_mgr.has_method("start_dedicated_server"):
		mp_mgr.start_dedicated_server(port, max_clients)
		print("[Server] Local LAN IP: %s -> Mobile clients connect to %s:%d" % [Protocol.get_local_ip(), Protocol.get_local_ip(), port])
	else:
		printerr("[Server] Could not find MultiplayerManager autoload!")
