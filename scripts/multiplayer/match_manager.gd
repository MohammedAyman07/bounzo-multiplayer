class_name MatchManager
extends RefCounted

# ==============================================================================
# MATCH MANAGER (Server-Side)
# Authoritative match orchestration, countdown, course seed, snapshot broadcasting,
# anti-cheat bounds checking, tie resolution, and rankings.
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")

signal match_started(room_code: String, course_seed: int)
signal match_ended(room_code: String, results: Array)
signal player_eliminated(room_code: String, peer_id: int, rank: int)

var room_manager: RefCounted

# Rate limiting tracking: peer_id -> Array of timestamps (seconds)
var _packet_timestamps: Dictionary = {}

func _init(rm: RefCounted) -> void:
	room_manager = rm

## Initialize and start a match countdown
func start_match_countdown(room_code: String) -> Dictionary:
	var room: Dictionary = room_manager.get_room(room_code)
	if room.is_empty():
		return {"success": false, "error": "Room not found"}

	var check = room_manager.can_start_match(room_code)
	if not check.can_start:
		return {"success": false, "error": check.reason}

	# Generate new authoritative course seed
	var course_seed: int = randi()
	room.state = Protocol.RoomState.COUNTDOWN
	room.match.seed = course_seed
	room.match.countdown = Protocol.COUNTDOWN_SECONDS
	room.match.start_time = Time.get_unix_time_from_system() + Protocol.COUNTDOWN_SECONDS
	room.match.timer = Protocol.MATCH_DURATION_SECONDS
	room.match.elapsed = 0.0

	# Reset player match stats
	for pid in room.players:
		var p: Dictionary = room.players[pid]
		p.status = Protocol.PlayerStatus.ALIVE
		p.score = 0
		p.height = 0.0
		p.x = 270.0
		p.y = -200.0
		p.vx = 0.0
		p.vy = 0.0
		p.eliminated_at = 0.0
		p.rank = 0

	print("[MatchManager] Room %s match starting with seed %d" % [room_code, course_seed])
	return {
		"success": true,
		"seed": course_seed,
		"countdown": Protocol.COUNTDOWN_SECONDS,
		"target_score": room.get("target_score", 2000),
		"difficulty": room.get("difficulty", "NORMAL")
	}

## Advance match timers and process states (called from server _process)
func process_matches(delta: float) -> Array:
	var state_events: Array = []

	for code in room_manager.rooms.keys():
		var room: Dictionary = room_manager.rooms[code]
		
		# Countdown handling
		if room.state == Protocol.RoomState.COUNTDOWN:
			room.match.countdown -= delta
			if room.match.countdown <= 0.0:
				room.state = Protocol.RoomState.IN_GAME
				state_events.append({
					"event": "game_start",
					"room_code": code,
					"room": room
				})
				match_started.emit(code, room.match.seed)
				print("[MatchManager] Room %s match started!" % code)

		# In-game match progress
		elif room.state == Protocol.RoomState.IN_GAME:
			room.match.elapsed += delta
			room.match.timer -= delta

			var alive_count: int = 0
			var total_players: int = room.players.size()
			var target_score: int = room.get("target_score", 2000)
			var target_reached: bool = false
			var target_winner_id: int = 0

			for pid in room.players:
				var p: Dictionary = room.players[pid]
				if p.status == Protocol.PlayerStatus.ALIVE:
					alive_count += 1
					if target_score > 0 and p.score >= target_score:
						target_reached = true
						target_winner_id = pid
						print("[MatchManager] Target score %d reached by player %s (%d)!" % [target_score, p.name, pid])

			# Match end conditions:
			# 1. Any player reached the target score (Race to Target!)
			# 2. In Target Score mode (target_score > 0): Living players get the chance to beat eliminated players' scores!
			#    Game continues while ANY player is alive, only ends when all are eliminated or timer expires.
			# 3. In Pure Survival mode (target_score == 0): Last Man Standing when alive_count <= 1.
			var should_end: bool = false
			if target_reached:
				should_end = true
			elif target_score > 0:
				if alive_count == 0:
					should_end = true
				elif room.match.timer <= 0.0:
					should_end = true
			else:
				if total_players >= 2 and alive_count <= 1:
					should_end = true
				elif total_players == 1 and alive_count == 0:
					should_end = true
				elif room.match.timer <= 0.0:
					should_end = true

			if should_end:
				var results: Array = finish_match(code)
				state_events.append({
					"event": "game_over",
					"room_code": code,
					"results": results
				})

	return state_events

## Receive and validate player update from network
func receive_player_update(peer_id: int, payload: Dictionary) -> bool:
	if not _validate_rate_limit(peer_id):
		return false

	var room: Dictionary = room_manager.get_room_by_peer(peer_id)
	if room.is_empty() or room.state != Protocol.RoomState.IN_GAME:
		return false

	var player: Dictionary = room.players.get(peer_id, {})
	if player.is_empty() or player.status != Protocol.PlayerStatus.ALIVE:
		return false

	# Validate position and movement delta sanity bounds
	var new_x = clamp(float(payload.get("x", 270.0)), -100.0, 700.0)
	var new_y = float(payload.get("y", -200.0))
	var new_vx = clamp(float(payload.get("vx", 0.0)), -1200.0, 1200.0)
	var new_vy = clamp(float(payload.get("vy", 0.0)), -2000.0, 2000.0)
	var reported_score = int(payload.get("score", 0))
	var is_eliminated = bool(payload.get("eliminated", false))

	# Player can only increase score reasonably
	if reported_score > player.score and (reported_score - player.score) < 5000:
		player.score = reported_score

	# In BOUNZO, height is climbed upwards (-y is higher)
	var current_height = -new_y
	if current_height > player.height:
		player.height = current_height

	player.x = new_x
	player.y = new_y
	player.vx = new_vx
	player.vy = new_vy

	if is_eliminated:
		player.status = Protocol.PlayerStatus.ELIMINATED
		player.eliminated_at = room.match.elapsed
		print("[MatchManager] Peer %d eliminated at elapsed time %.2fs" % [peer_id, player.eliminated_at])

	return true

## Build snapshot for room players
func get_room_snapshot(room_code: String) -> Array:
	var room: Dictionary = room_manager.get_room(room_code)
	if room.is_empty():
		return []

	var snapshot: Array = []
	for pid in room.players:
		var p: Dictionary = room.players[pid]
		snapshot.append({
			"peer_id": p.peer_id,
			"slot": p.slot,
			"name": p.name,
			"x": p.get("x", 270.0),
			"y": p.get("y", -200.0),
			"vx": p.get("vx", 0.0),
			"vy": p.get("vy", 0.0),
			"score": p.score,
			"height": p.height,
			"status": p.status
		})

	return snapshot

## Finish match and calculate authoritative deterministic rankings
func finish_match(room_code: String) -> Array:
	var room: Dictionary = room_manager.get_room(room_code)
	if room.is_empty():
		return []

	room.state = Protocol.RoomState.RESULTS
	var target_score: int = room.get("target_score", 2000)

	var player_list: Array = []
	for pid in room.players:
		player_list.append(room.players[pid])

	# Deterministic sorting:
	# 1. Target Score Winner: Player who reached target_score takes priority
	# 2. Survival State: ALIVE players rank above ELIMINATED players
	# 3. For ALIVE players: Higher Score -> Higher Height
	# 4. For ELIMINATED players: Later elimination time (survived longer) -> Higher Score
	# 5. Tie-breaker: Lower peer_id
	player_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_reached: bool = (target_score > 0 and a.score >= target_score)
		var b_reached: bool = (target_score > 0 and b.score >= target_score)
		if a_reached != b_reached:
			return a_reached

		if target_score > 0:
			# Target Score Mode: HIGHEST SCORE WINS! (e.g. 550 score beats 500 score)
			if a.score != b.score:
				return a.score > b.score
			if a.height != b.height:
				return a.height > b.height
			var a_alive: bool = (a.status == Protocol.PlayerStatus.ALIVE)
			var b_alive: bool = (b.status == Protocol.PlayerStatus.ALIVE)
			if a_alive != b_alive:
				return a_alive
			if a.eliminated_at != b.eliminated_at:
				return a.eliminated_at > b.eliminated_at
			return a.peer_id < b.peer_id
		else:
			# Pure Survival / LMS Mode (target_score == 0):
			var a_alive: bool = (a.status == Protocol.PlayerStatus.ALIVE)
			var b_alive: bool = (b.status == Protocol.PlayerStatus.ALIVE)
			if a_alive != b_alive:
				return a_alive
			if a.eliminated_at != b.eliminated_at:
				return a.eliminated_at > b.eliminated_at
			if a.score != b.score:
				return a.score > b.score
			if a.height != b.height:
				return a.height > b.height
			return a.peer_id < b.peer_id
	)

	# Assign ranks 1..N
	var results: Array = []
	for i in range(player_list.size()):
		var p = player_list[i]
		p.rank = i + 1
		results.append({
			"rank": p.rank,
			"peer_id": p.peer_id,
			"name": p.name,
			"slot": p.slot,
			"score": p.score,
			"height": p.height,
			"cosmetics": p.cosmetics
		})

	match_ended.emit(room_code, results)
	print("[MatchManager] Room %s match finished. Winner: %s with score %d" % [room_code, results[0].name, results[0].score])
	return results

## Prepare a room for rematch
func prepare_rematch(room_code: String) -> Dictionary:
	var room: Dictionary = room_manager.get_room(room_code)
	if room.is_empty():
		return {"success": false, "error": "Room not found"}

	room.state = Protocol.RoomState.LOBBY
	for pid in room.players:
		var p: Dictionary = room.players[pid]
		p.ready = (pid == room.host_id) # Host is ready, others ready up
		p.status = Protocol.PlayerStatus.ALIVE
		p.score = 0
		p.height = 0.0
		p.rank = 0

	return {"success": true, "room": room}

## Anti-spam rate limiting helper
func _validate_rate_limit(peer_id: int) -> bool:
	var now = Time.get_unix_time_from_system()
	if not _packet_timestamps.has(peer_id):
		_packet_timestamps[peer_id] = []

	var timestamps: Array = _packet_timestamps[peer_id]
	# Retain only timestamps from the last 1.0 second
	while timestamps.size() > 0 and (now - timestamps[0]) > 1.0:
		timestamps.pop_front()

	if timestamps.size() >= Protocol.MAX_PACKETS_PER_SECOND:
		return false

	timestamps.append(now)
	return true

func clear_peer(peer_id: int) -> void:
	_packet_timestamps.erase(peer_id)
