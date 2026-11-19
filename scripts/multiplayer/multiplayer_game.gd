class_name MultiplayerGame
extends Node2D

# ==============================================================================
# MULTIPLAYER GAME CONTROLLER (4-Player Survival Race)
# Orchestrates local player, seeded platforms, remote opponents, live HUD,
# touch controls, and spectator camera.
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")
const RemotePlayerScene = preload("res://scenes/multiplayer/remote_player.tscn")

const VIEWPORT_W: float = 540.0
const VIEWPORT_H: float = 960.0
const PLAYER_START = Vector2(270.0, -200.0)

# Autoload lookups
var _mp_mgr: Node:
	get: return get_node_or_null("/root/MultiplayerManager")
var _ui_theme: Node:
	get: return get_node_or_null("/root/UITheme")
var _audio: Node:
	get: return get_node_or_null("/root/AudioManager")
var _ad_mgr: Node:
	get: return get_node_or_null("/root/AdManager")

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera
@onready var background: Node2D = $Background
@onready var platform_gen: Node2D = $PlatformGenerator
@onready var remote_container: Node2D = $RemotePlayers

# HUD Elements
@onready var hud: Control = $UILayer/HUD
@onready var timer_badge: PanelContainer = $UILayer/HUD/SafeContainer/HUDVBox/HeaderBar/TimerBadge
@onready var timer_label: Label = $UILayer/HUD/SafeContainer/HUDVBox/HeaderBar/TimerBadge/TimerLabel
@onready var score_title: Label = $UILayer/HUD/SafeContainer/HUDVBox/HeaderBar/ScoreContainer/ScoreTitle
@onready var score_label: Label = $UILayer/HUD/SafeContainer/HUDVBox/HeaderBar/ScoreContainer/ScoreLabel
@onready var rank_badge: PanelContainer = $UILayer/HUD/SafeContainer/HUDVBox/HeaderBar/RankBadge
@onready var rank_label: Label = $UILayer/HUD/SafeContainer/HUDVBox/HeaderBar/RankBadge/RankLabel
@onready var opponents_box: HBoxContainer = $UILayer/HUD/SafeContainer/HUDVBox/OpponentsBar
@onready var spectator_banner: PanelContainer = $UILayer/HUD/SafeContainer/HUDVBox/SpectatorBanner
@onready var spectator_label: Label = $UILayer/HUD/SafeContainer/HUDVBox/SpectatorBanner/SpectatorLabel
@onready var race_tracker: Control = $UILayer/HUD/RaceTracker
@onready var countdown_overlay: Control = $UILayer/CountdownOverlay
@onready var countdown_label: Label = $UILayer/CountdownOverlay/CountdownLabel

var local_score: int = 0
var target_score: int = 2000
var highest_y: float = -200.0
var is_game_active: bool = false
var match_timer: float = Protocol.MATCH_DURATION_SECONDS
var update_timer: float = 0.0

var _shake_amount: float = 0.0
var _shake_timer: float = 0.0

var opponents: Dictionary = {}        # peer_id -> RemotePlayer node
var opponent_cards: Dictionary = {}   # peer_id -> Label stat_lbl
var opponent_scores: Dictionary = {}  # peer_id -> int score

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	# Hide ad banners during match
	if _ad_mgr != null and _ad_mgr.has_method("hide_banner"):
		_ad_mgr.hide_banner()

	# Start background music
	if _audio != null and _audio.has_method("play_music"):
		_audio.play_music()

	# Apply theme styling to HUD badges
	_apply_hud_styling()

	# Setup Camera & Background
	if camera.has_method("setup"):
		camera.setup(player, VIEWPORT_H)
	if background.has_method("setup"):
		background.setup(camera, VIEWPORT_W, VIEWPORT_H)

	# Connect local player
	player.landed_on_platform.connect(_on_player_landed)
	player.player_died.connect(_on_player_died)
	player.reset(PLAYER_START)

	# Connect MultiplayerManager signals
	if _mp_mgr != null:
		_mp_mgr.snapshot_received.connect(_on_snapshot_received)
		_mp_mgr.match_results_received.connect(_on_match_results_received)
		_mp_mgr.countdown_started.connect(_on_countdown_started)
		_mp_mgr.match_started.connect(_on_match_started)
		if _mp_mgr.current_room.has("target_score"):
			target_score = int(_mp_mgr.current_room.get("target_score", 2000))

	var diff_name: String = "NORMAL"
	if _mp_mgr != null:
		if _mp_mgr.current_room.has("difficulty"):
			diff_name = str(_mp_mgr.current_room.get("difficulty", "NORMAL"))
		elif _mp_mgr.current_difficulty != "":
			diff_name = _mp_mgr.current_difficulty

	if target_score > 0:
		score_title.text = "GOAL: %d [%s]" % [target_score, diff_name]
	else:
		score_title.text = "SURVIVAL [%s]" % diff_name

	_setup_course()
	_setup_players()
	_start_countdown()

func _apply_hud_styling() -> void:
	if _ui_theme != null and _ui_theme.has_method("glass_panel"):
		timer_badge.add_theme_stylebox_override("panel", _ui_theme.glass_panel(UITheme.RADIUS_SM))
		rank_badge.add_theme_stylebox_override("panel", _ui_theme.glass_panel(UITheme.RADIUS_SM))
		spectator_banner.add_theme_stylebox_override("panel", _ui_theme.glass_panel_accent(Color(1, 0.2, 0.3), UITheme.RADIUS_SM))

func _setup_course() -> void:
	var seed_val: int = _mp_mgr.current_course_seed if _mp_mgr != null else 0
	if seed_val == 0:
		seed_val = randi()
	var diff: String = "NORMAL"
	if _mp_mgr != null:
		if _mp_mgr.current_room.has("difficulty"):
			diff = str(_mp_mgr.current_room.get("difficulty", "NORMAL"))
		elif _mp_mgr.current_difficulty != "":
			diff = _mp_mgr.current_difficulty
	platform_gen.initialize(seed_val, PLAYER_START, VIEWPORT_W, diff)

func _setup_players() -> void:
	if _mp_mgr == null or _mp_mgr.current_room.is_empty():
		return

	var room = _mp_mgr.current_room
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	for p in room.players:
		var pid: int = int(p.peer_id)
		if pid == local_id:
			var slot: int = int(p.slot)
			if slot >= 0 and slot < Protocol.SLOT_COLORS.size():
				player.modulate = Protocol.SLOT_COLORS[slot]
		else:
			_spawn_remote_player(p)

	_build_opponents_hud()

func _spawn_remote_player(p_data: Dictionary) -> void:
	var pid: int = int(p_data.peer_id)
	var remote: Node2D = RemotePlayerScene.instantiate()
	remote.position = PLAYER_START
	remote_container.add_child(remote)
	remote.setup(pid, int(p_data.slot), str(p_data.name), p_data.get("cosmetics", {}))
	opponents[pid] = remote
	opponent_scores[pid] = 0

func _build_opponents_hud() -> void:
	for child in opponents_box.get_children():
		child.queue_free()
	opponent_cards.clear()

	for pid in opponents:
		var remote: Node2D = opponents[pid]
		var card = PanelContainer.new()
		if _ui_theme != null and _ui_theme.has_method("glass_panel_accent"):
			card.add_theme_stylebox_override("panel", _ui_theme.glass_panel_accent(remote._slot_color, UITheme.RADIUS_SM))

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		card.add_child(hbox)

		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = remote._slot_color
		hbox.add_child(dot)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		hbox.add_child(vbox)

		var name_lbl = Label.new()
		name_lbl.text = remote.player_name
		name_lbl.label_settings = UITheme.ls(11, Color(0.85, 0.85, 0.9)) if _ui_theme else null
		vbox.add_child(name_lbl)

		var stat_lbl = Label.new()
		stat_lbl.text = "0 pts"
		stat_lbl.label_settings = UITheme.ls(11, remote._slot_color) if _ui_theme else null
		vbox.add_child(stat_lbl)

		opponents_box.add_child(card)
		opponent_cards[pid] = stat_lbl

func _start_countdown() -> void:
	is_game_active = false
	countdown_overlay.show()
	_animate_countdown(3)

func _animate_countdown(number: int) -> void:
	if number > 0:
		countdown_label.text = str(number)
		countdown_label.scale = Vector2(0.5, 0.5)
		if _audio != null and _audio.has_method("play"):
			_audio.play("button")
		var t = create_tween().set_parallel(true)
		t.tween_property(countdown_label, "scale", Vector2(1.2, 1.2), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(func(): _animate_countdown(number - 1))
	else:
		countdown_label.text = "GO!"
		countdown_label.scale = Vector2(1.5, 1.5)
		if _audio != null and _audio.has_method("play"):
			_audio.play("perfect")
		var t = create_tween()
		t.tween_property(countdown_label, "modulate:a", 0.0, 0.5)
		t.tween_callback(func():
			countdown_overlay.hide()
			is_game_active = true
		)

func _on_countdown_started(_info: Dictionary) -> void:
	_start_countdown()

func _on_match_started(_seed: int) -> void:
	is_game_active = true
	countdown_overlay.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not is_game_active or not player.is_alive:
		return

	var dir: float = 0.0
	var handled: bool = false

	if event is InputEventScreenTouch:
		if event.pressed:
			dir = _x_to_direction(event.position.x)
			handled = true
	elif event is InputEventScreenDrag:
		dir = _x_to_direction(event.position.x)
		handled = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dir = _x_to_direction(event.position.x)
			handled = true
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dir = _x_to_direction(event.position.x)
		handled = true
	elif event.is_action("ui_left") or event.is_action("ui_right"):
		dir = Input.get_axis("ui_left", "ui_right")
		handled = true

	if handled:
		player.set_direction(dir)

func _x_to_direction(screen_x: float) -> float:
	var vp_w: float = get_viewport().get_visible_rect().size.x
	return -1.0 if screen_x < vp_w * 0.5 else 1.0

func _process(delta: float) -> void:
	if is_game_active:
		match_timer = max(0.0, match_timer - delta)
		var mins = int(match_timer) / 60
		var secs = int(match_timer) % 60
		timer_label.text = "%02d:%02d" % [mins, secs]

		# Camera update matching single player
		if player.is_alive:
			var target_x = player.global_position.x
			camera.global_position.x = lerp(camera.global_position.x, target_x, 5.0 * delta)
		else:
			_spectate_leading_opponent(delta)

		# Screen shake
		if _shake_timer > 0.0:
			_shake_timer -= delta
			var shake_x = randf_range(-_shake_amount, _shake_amount)
			var shake_y = randf_range(-_shake_amount * 0.5, _shake_amount * 0.5)
			camera.offset = Vector2(shake_x, shake_y)
		else:
			camera.offset = Vector2.ZERO

		# Death zone check (below camera bottom)
		var death_y = camera.global_position.y + (VIEWPORT_H * 0.5) + 300.0
		if player.is_alive and player.global_position.y > death_y:
			player.die()

		# Send 20 Hz updates to authoritative server
		update_timer += delta
		if update_timer >= Protocol.POSITION_UPDATE_INTERVAL:
			update_timer = 0.0
			_send_local_update()

		_update_rank_badge()

func _shake_screen(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_timer = duration

func _spectate_leading_opponent(delta: float) -> void:
	var lead_y: float = 999999.0
	var lead_pos: Vector2 = Vector2.ZERO
	var lead_name: String = ""
	var lead_score: int = 0
	var has_lead: bool = false

	for pid in opponents:
		var opp: Node2D = opponents[pid]
		if opp.is_alive and opp.global_position.y < lead_y:
			lead_y = opp.global_position.y
			lead_pos = opp.global_position
			lead_name = opp.player_name
			lead_score = opponent_scores.get(pid, 0)
			has_lead = true

	if has_lead:
		camera.global_position = camera.global_position.lerp(lead_pos, 4.0 * delta)
		spectator_label.text = "👁️ SPECTATING: %s (%d PTS)" % [lead_name.to_upper(), lead_score]
	else:
		spectator_label.text = "MATCH COMPLETED"

func _send_local_update() -> void:
	if _mp_mgr == null: return
	_mp_mgr.send_position_update({
		"x": player.global_position.x,
		"y": player.global_position.y,
		"vx": player.velocity.x,
		"vy": player.velocity.y,
		"score": local_score,
		"eliminated": not player.is_alive
	})

func _on_player_landed(platform_body: Node) -> void:
	if not is_game_active or not player.is_alive:
		return

	# Audio & Shake feedback
	_shake_screen(2.5, 0.1)

	var is_perfect: bool = false
	if is_instance_valid(platform_body) and platform_body.has_method("get_safe_center_x"):
		var safe_center: float = platform_body.get_safe_center_x()
		var safe_width: float = platform_body.get_safe_width()
		var dist = abs(player.global_position.x - safe_center)
		if dist <= safe_width * 0.15:
			is_perfect = true

	if is_perfect:
		local_score += 25
		if _audio != null and _audio.has_method("play"):
			_audio.play("perfect")
	else:
		local_score += 10
		if _audio != null and _audio.has_method("play"):
			_audio.play("land")

	score_label.text = str(local_score)

	# Score scale pulse tween
	var st = create_tween()
	st.tween_property(score_label, "scale", Vector2(1.15, 1.15), 0.08)
	st.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.12)

func _on_player_died() -> void:
	_shake_screen(8.0, 0.35)
	if _audio != null and _audio.has_method("play"):
		_audio.play("gameover")
	spectator_banner.show()
	var reason = player.death_reason if ("death_reason" in player and player.death_reason != "") else "ELIMINATED"
	spectator_label.text = "%s — SPECTATING" % reason.to_upper()
	_send_local_update()

func _update_rank_badge() -> void:
	var my_rank: int = 1
	for pid in opponent_scores:
		if opponent_scores[pid] > local_score:
			my_rank += 1
	var total_players = opponents.size() + 1
	rank_label.text = "RANK #%d" % my_rank

func _on_snapshot_received(snapshot: Array) -> void:
	var alive_opponents: int = 0
	for entry in snapshot:
		var pid: int = int(entry.peer_id)
		if opponents.has(pid):
			var opp: Node2D = opponents[pid]
			var alive: bool = (int(entry.status) == Protocol.PlayerStatus.ALIVE)
			if alive:
				alive_opponents += 1
			opp.update_network_state(float(entry.x), float(entry.y), alive)

			var score_val = int(entry.score)
			opponent_scores[pid] = score_val

			if opponent_cards.has(pid):
				var status_text = "%d pts" % score_val
				if not alive:
					status_text = "OUT (%d)" % score_val
				opponent_cards[pid].text = status_text

	# Dynamic banner feedback for active player
	if player.is_alive and opponents.size() > 0:
		if target_score > 0 and local_score >= target_score:
			spectator_banner.show()
			spectator_label.text = "🎯 TARGET REACHED (%d PTS)! WINNER!" % target_score
		elif alive_opponents == 0:
			var max_opp_score: int = 0
			for pid in opponent_scores:
				max_opp_score = max(max_opp_score, opponent_scores[pid])
			spectator_banner.show()
			if local_score > max_opp_score:
				spectator_label.text = "👑 YOU BEAT ALL OPPONENTS (%d PTS)! KEEP CLIMBING!" % local_score
			else:
				var need_pts = (max_opp_score - local_score) + 1
				spectator_label.text = "🔥 LEADER OUT AT %d PTS! NEED %d MORE TO WIN!" % [max_opp_score, need_pts]

func _on_match_results_received(results: Array) -> void:
	is_game_active = false
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_results.tscn")
