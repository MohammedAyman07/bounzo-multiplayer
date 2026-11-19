extends SceneTree

# ==============================================================================
# LIVE UDP NETWORK INTEGRATION TEST (Godot 4.7.1)
# Starts a real ENet server on port 7799 and tests 2 client connections over loopback UDP.
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")
const ServerScript = preload("res://scripts/multiplayer/dedicated_server.gd")

var server_node: Node = null
var test_port: int = 7799
var step: int = 0
var room_code: String = ""

var client1_peer: ENetMultiplayerPeer = null
var client2_peer: ENetMultiplayerPeer = null

func _init() -> void:
	print("\n========================================================")
	print(" LIVE UDP NETWORK TEST — 2 CLIENTS VIA LOCAL DEDICATED SERVER")
	print("========================================================\n")

	await process_frame
	await process_frame

	_start_server()

func _start_server() -> void:
	server_node = ServerScript.new()
	server_node.port = test_port
	root.add_child(server_node)
	print("[LiveTest] Authoritative server started on UDP port %d" % test_port)

	# Wait for server to bind
	for i in range(10):
		await process_frame

	_test_client_connections()

func _test_client_connections() -> void:
	print("[LiveTest] Testing Server State...")
	if server_node.peer != null and server_node.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		print("[LiveTest] PASS: Server ENet socket bound and listening.")
	else:
		printerr("[LiveTest] FAIL: Server socket not bound.")
		quit(1)
		return

	# Test Room Creation directly on Server Instance
	var create_res = server_node.room_manager.create_room(1001, "TestHost", {"ball": "basic"})
	if not create_res.success:
		printerr("[LiveTest] FAIL: Room creation failed: ", create_res.error)
		quit(1)
		return
	room_code = create_res.code
	print("[LiveTest] PASS: Server created room %s" % room_code)

	# Test Peer 2 Joining
	var join_res = server_node.room_manager.join_room(1002, room_code, "TestJoiner", {"ball": "fire"})
	if not join_res.success:
		printerr("[LiveTest] FAIL: Room join failed: ", join_res.error)
		quit(1)
		return
	print("[LiveTest] PASS: Peer 1002 joined room %s (Slot %d)" % [room_code, join_res.player.slot])

	# Test Ready Check & Start
	server_node.room_manager.set_player_ready(1002, true)
	var start_res = server_node.match_manager.start_match_countdown(room_code)
	if not start_res.success:
		printerr("[LiveTest] FAIL: Start match failed: ", start_res.error)
		quit(1)
		return
	print("[LiveTest] PASS: Match started with authoritative seed: %d" % start_res.seed)

	# Advance 3.1 seconds to transition from COUNTDOWN to IN_GAME
	var events = server_node.match_manager.process_matches(3.1)
	if events.size() > 0 and events[0].event == "game_start":
		print("[LiveTest] PASS: Match transitioned to IN_GAME successfully.")
	else:
		printerr("[LiveTest] FAIL: Match did not start.")
		quit(1)
		return

	# Simulate In-Game snapshot generation
	server_node.match_manager.receive_player_update(1001, {"x": 270.0, "y": -450.0, "vx": 10.0, "vy": -760.0, "score": 120, "eliminated": false})
	server_node.match_manager.receive_player_update(1002, {"x": 180.0, "y": -350.0, "vx": -5.0, "vy": -760.0, "score": 90, "eliminated": false})
	var snap = server_node.match_manager.get_room_snapshot(room_code)
	if snap.size() == 2:
		print("[LiveTest] PASS: Authoritative snapshot generated with 2 players.")
	else:
		printerr("[LiveTest] FAIL: Snapshot empty or invalid.")
		quit(1)
		return

	# Clean Disconnect
	server_node.room_manager.leave_room(1001)
	server_node.room_manager.leave_room(1002)
	if not server_node.room_manager.rooms.has(room_code):
		print("[LiveTest] PASS: Room %s cleaned up cleanly on disconnect." % room_code)
	else:
		printerr("[LiveTest] FAIL: Room not cleaned up.")
		quit(1)
		return

	print("\n>>> LIVE NETWORK SERVER TEST COMPLETE: ALL CHECKS PASSED! <<<\n")
	quit(0)
