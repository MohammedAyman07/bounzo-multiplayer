class_name RoomManager
extends RefCounted

# ==============================================================================
# ROOM MANAGER (Server-Side)
# Manages room lifecycle, 5-char room codes, max 4 players, ready state, and cleanup
const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")

var rooms: Dictionary = {}         # room_code -> Dictionary
var peer_to_room: Dictionary = {}  # peer_id -> room_code

## Create a new private room
func create_room(host_id: int, host_name: String, cosmetics: Dictionary) -> Dictionary:
	# If host already in a room, leave first
	if peer_to_room.has(host_id):
		leave_room(host_id)

	# Generate unique 5-char code
	var code: String = ""
	var attempts: int = 0
	while attempts < 100:
		code = Protocol.generate_room_code()
		if not rooms.has(code):
			break
		attempts += 1

	if rooms.has(code):
		return {"success": false, "error": "Failed to allocate unique room code"}

	var clean_name: String = Protocol.sanitize_player_name(host_name)
	
	var player_data = {
		"peer_id": host_id,
		"name": clean_name,
		"slot": 0,
		"ready": true, # Host is ready by default
		"cosmetics": cosmetics,
		"status": Protocol.PlayerStatus.ALIVE,
		"score": 0,
		"height": 0.0,
		"eliminated_at": 0.0,
		"rank": 0
	}

	var room_data = {
		"code": code,
		"host_id": host_id,
		"created_at": Time.get_unix_time_from_system(),
		"state": Protocol.RoomState.LOBBY,
		"players": {
			host_id: player_data
		},
		"available_slots": [1, 2, 3],
		"target_score": 2000, # min 1000 to max 100000 (or 0 for survival)
		"difficulty": "NORMAL", # EASY, NORMAL, HARD, INSANE
		"match": {
			"seed": 0,
			"start_ticks": 0,
			"timer": Protocol.MATCH_DURATION_SECONDS
		}
	}

	rooms[code] = room_data
	peer_to_room[host_id] = code
	print("[RoomManager] Room %s created by host %d (%s)" % [code, host_id, clean_name])

	return {
		"success": true,
		"code": code,
		"room": room_data
	}

## Join an existing room
func join_room(peer_id: int, raw_code: String, player_name: String, cosmetics: Dictionary) -> Dictionary:
	if peer_to_room.has(peer_id):
		leave_room(peer_id)

	var code: String = raw_code.strip_edges().to_upper()
	if not Protocol.is_valid_room_code_format(code):
		return {"success": false, "error": "Invalid room code format"}

	if not rooms.has(code):
		return {"success": false, "error": "Room not found"}

	var room: Dictionary = rooms[code]

	if room.state != Protocol.RoomState.LOBBY:
		return {"success": false, "error": "Match has already started in this room"}

	var players: Dictionary = room.players
	if players.size() >= Protocol.MAX_PLAYERS_PER_ROOM:
		return {"success": false, "error": "Room is full (max 4 players)"}

	var available_slots: Array = room.available_slots
	if available_slots.is_empty():
		return {"success": false, "error": "No available player slots"}

	var slot: int = available_slots.pop_front()
	var clean_name: String = Protocol.sanitize_player_name(player_name)

	var player_data = {
		"peer_id": peer_id,
		"name": clean_name,
		"slot": slot,
		"ready": false,
		"cosmetics": cosmetics,
		"status": Protocol.PlayerStatus.ALIVE,
		"score": 0,
		"height": 0.0,
		"eliminated_at": 0.0,
		"rank": 0
	}

	players[peer_id] = player_data
	peer_to_room[peer_id] = code
	print("[RoomManager] Peer %d (%s) joined room %s (Slot %d)" % [peer_id, clean_name, code, slot])

	return {
		"success": true,
		"code": code,
		"room": room,
		"player": player_data
	}

## Set player ready state
func set_player_ready(peer_id: int, is_ready: bool) -> Dictionary:
	if not peer_to_room.has(peer_id):
		return {"success": false, "error": "Player not in a room"}

	var code: String = peer_to_room[peer_id]
	var room: Dictionary = rooms[code]

	if not room.players.has(peer_id):
		return {"success": false, "error": "Player not in room registry"}

	# Host is always ready, others can toggle
	room.players[peer_id].ready = is_ready
	return {"success": true, "code": code, "room": room}

## Leave current room
func leave_room(peer_id: int) -> Dictionary:
	if not peer_to_room.has(peer_id):
		return {"success": false, "error": "Not in any room"}

	var code: String = peer_to_room[peer_id]
	peer_to_room.erase(peer_id)

	if not rooms.has(code):
		return {"success": true, "code": code, "room_deleted": true}

	var room: Dictionary = rooms[code]
	var player_data: Dictionary = room.players.get(peer_id, {})
	var slot: int = player_data.get("slot", -1)
	room.players.erase(peer_id)

	if slot != -1 and not room.available_slots.has(slot):
		room.available_slots.append(slot)
		room.available_slots.sort()

	print("[RoomManager] Peer %d left room %s" % [peer_id, code])

	# If room is now empty, delete it
	if room.players.is_empty():
		rooms.erase(code)
		print("[RoomManager] Room %s is empty and was removed" % code)
		return {"success": true, "code": code, "room_deleted": true}

	# If host left, migrate host to next oldest player
	var host_changed: bool = false
	if room.host_id == peer_id:
		var remaining_peers: Array = room.players.keys()
		room.host_id = remaining_peers[0]
		room.players[room.host_id].ready = true
		host_changed = true
		print("[RoomManager] Host transferred to peer %d in room %s" % [room.host_id, code])

	return {
		"success": true,
		"code": code,
		"room": room,
		"host_changed": host_changed,
		"new_host_id": room.host_id,
		"room_deleted": false
	}

## Check if room can start match
func can_start_match(code: String) -> Dictionary:
	if not rooms.has(code):
		return {"can_start": false, "reason": "Room not found"}

	var room: Dictionary = rooms[code]
	var players: Dictionary = room.players

	if players.size() < Protocol.MIN_PLAYERS_TO_START:
		return {"can_start": false, "reason": "Need at least 2 players to start"}

	for pid in players:
		if not players[pid].ready:
			return {"can_start": false, "reason": "All players must be ready"}

	return {"can_start": true, "room": room}

## Retrieve room by peer ID
func get_room_by_peer(peer_id: int) -> Dictionary:
	if not peer_to_room.has(peer_id):
		return {}
	var code: String = peer_to_room[peer_id]
	return rooms.get(code, {})

## Retrieve room by room code
func get_room(code: String) -> Dictionary:
	return rooms.get(code.to_upper(), {})

## Set room target score (only host can do this, min 1000 to max 100000 or 0 for survival)
func set_room_target_score(room_code: String, sender_id: int, target_score: int) -> Dictionary:
	var room: Dictionary = get_room(room_code)
	if room.is_empty():
		return {"success": false, "error": "Room not found"}
	if room.host_id != sender_id:
		return {"success": false, "error": "Only host can change target score"}
	if room.state != Protocol.RoomState.LOBBY:
		return {"success": false, "error": "Cannot change target score during match"}

	if target_score > 0:
		target_score = clamp(target_score, 1000, 100000)
	room.target_score = target_score
	print("[RoomManager] Room %s target score set to %d by host %d" % [room_code, target_score, sender_id])
	return {"success": true, "target_score": target_score, "room": room}

## Set room difficulty (only host can do this)
func set_room_difficulty(room_code: String, sender_id: int, difficulty: String) -> Dictionary:
	var room: Dictionary = get_room(room_code)
	if room.is_empty():
		return {"success": false, "error": "Room not found"}
	if room.host_id != sender_id:
		return {"success": false, "error": "Only host can change difficulty"}
	if room.state != Protocol.RoomState.LOBBY:
		return {"success": false, "error": "Cannot change difficulty during match"}

	var clean_diff = difficulty.to_upper().strip_edges()
	if not clean_diff in ["EASY", "NORMAL", "HARD", "INSANE"]:
		clean_diff = "NORMAL"

	room.difficulty = clean_diff
	print("[RoomManager] Room %s difficulty set to %s by host %d" % [room_code, clean_diff, sender_id])
	return {"success": true, "difficulty": clean_diff, "room": room}

## Serialize room state for network transfer
static func serialize_room_state(room: Dictionary) -> Dictionary:
	var players_summary: Array = []
	for pid in room.players:
		var p: Dictionary = room.players[pid]
		players_summary.append({
			"peer_id": p.peer_id,
			"name": p.name,
			"slot": p.slot,
			"ready": p.ready,
			"cosmetics": p.cosmetics,
			"status": p.status,
			"score": p.score,
			"height": p.height,
			"rank": p.rank
		})

	return {
		"code": room.code,
		"host_id": room.host_id,
		"state": room.state,
		"target_score": room.get("target_score", 2000),
		"difficulty": room.get("difficulty", "NORMAL"),
		"players": players_summary,
		"player_count": room.players.size(),
		"match": room.match
	}
