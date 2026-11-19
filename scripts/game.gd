extends Node2D

# =====================================================
# GAME MANAGER
# Orchestrates all Phase 2 systems.
# =====================================================

# --- Node references (pre-existing in .tscn) ---
@onready var player: CharacterBody2D   = $Player
@onready var camera: Camera2D          = $Camera
@onready var platform_gen: Node2D      = $PlatformGenerator
@onready var background: Node2D        = $Background

@onready var score_label: Label        = $UILayer/HUD/ScoreContainer/ScoreLabel
@onready var game_over_panel: Control  = $UILayer/GameOverPanel
@onready var pause_btn: Button         = $UILayer/HUD/PauseBtn
@onready var pause_panel: Control      = $UILayer/PausePanel
@onready var resume_btn: Button        = $UILayer/PausePanel/VBox/ResumeBtn
@onready var restart_btn: Button       = $UILayer/PausePanel/VBox/RestartBtn

var tutorial_manager: Node = null

# Dynamically-created nodes (built by ui_builder.gd)
var main_menu_panel: Control = null
var play_btn: Button = null
# Phase 2 HUD labels (created dynamically by ui_builder.gd)
var chain_label: Label = null
var multiplier_label: Label = null
# Game Over extra labels
var go_best_score_value: Label = null
var go_chain_value: Label = null
var go_best_chain_value: Label = null
var go_new_record_label: Label = null
var go_score_value: Label = null
var try_again_btn: Button = null
var watch_ad_btn: Button = null

# --- CONSTANTS ---
const VIEWPORT_W: float   = 540.0
const VIEWPORT_H: float   = 960.0
const PLAYER_START        = Vector2(270.0, -200.0)

@export var death_margin: float = 300.0

# Perfect landing: within what fraction of platform width counts as "perfect"
const PERFECT_THRESHOLD: float = 0.20

# --- STATE ---
enum State { MENU, PLAYING, GAME_OVER, PAUSED, COUNTDOWN }
var _state: State = State.MENU

# --- Camera shake ---
var _shake_amount: float = 0.0
var _shake_timer: float = 0.0
var _camera_base_x: float = 270.0

# --- Milestone tracking (to detect when multiplier just changed) ---
var _last_multiplier: int = 1

# --- Coins earned this run ---
var _session_coins: int = 0
var _revive_used: bool = false
var _pending_interstitial_action: String = ""

var _phase_banner: Label
var _phase_tween: Tween

var _best_score_hud: Label
var _streak_label: Label
var _streak_tween: Tween
var _fever_overlay: ColorRect
var _fever_label: Label
var _fever_active: bool = false
var _last_tracked_score: int = 0

# Challenge Mode UI elements
var _chal_timer_lbl: Label
var _chal_target_lbl: Label
var _chal_progress_lbl: Label
var _chal_progress_bar: ProgressBar

func _ready() -> void:
	get_tree().quit_on_go_back = false
	player.landed_on_platform.connect(_on_player_landed)
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	
	AdManager.rewarded_ad_completed.connect(_on_rewarded_ad_completed)
	AdManager.rewarded_ad_failed.connect(_on_rewarded_ad_failed)
	AdManager.interstitial_closed.connect(_on_interstitial_closed)
	
	DailyChallengeManager.challenge_completed.connect(_on_daily_completed)
	MissionManager.mission_completed.connect(_on_mission_completed)
	
	GameEvents.score_changed.connect(_on_score_changed)
	player.player_died.connect(_on_player_died)
	
	camera.setup(player, VIEWPORT_H)
	platform_gen.initialize(PLAYER_START, VIEWPORT_W)
	background.setup(camera, VIEWPORT_W, VIEWPORT_H)
	
	tutorial_manager = preload("res://scripts/tutorial_manager.gd").new()
	add_child(tutorial_manager)
	tutorial_manager.setup(self)

	_camera_base_x = camera.global_position.x
	call_deferred("_connect_dynamic_ui")
	
	var wpm = get_node_or_null("/root/WorldPhaseManager")
	if wpm:
		wpm.phase_changed.connect(_show_phase_banner)
		
	# Start music if it's not already playing (e.g. bypassed splash screen)
	AudioManager.play_music()

func _reset_game_state() -> void:
	player.global_position = PLAYER_START
	player.reset(PLAYER_START)
	camera.global_position = Vector2(270, 480)
	camera._is_shaking = false
	camera.set_deferred("global_position", Vector2(270, 480))
	camera.reset_smoothing()
	platform_gen.clear_all()
	platform_gen.initialize(PLAYER_START, VIEWPORT_W)
	_last_tracked_score = 0
	
	if is_instance_valid(_fever_label):
		_fever_label.hide()
		_fever_label.modulate.a = 1.0
	_fever_active = false
	
	var wpm = get_node_or_null("/root/WorldPhaseManager")
	if wpm: wpm.reset()

func _connect_dynamic_ui() -> void:
	main_menu_panel = $UILayer/MainMenuPanel
	# PlayBtn is now a direct child of the VBox inside MainMenuPanel (no top/bottom bar wrappers)
	play_btn        = $UILayer.find_child("PlayBtn",         true, false)
	chain_label     = $UILayer/HUD/ScoreContainer/ChainLabel
	multiplier_label = $UILayer/HUD/ScoreContainer/MultiplierLabel

	# Use find_child with owned=false because labels are dynamically added by ui_builder
	var go_vbox = game_over_panel.get_node("VBox")
	go_best_score_value  = go_vbox.find_child("BestScoreValue",  true, false)
	go_chain_value       = go_vbox.find_child("ChainValue",      true, false)
	go_best_chain_value  = go_vbox.find_child("BestChainValue",  true, false)
	go_new_record_label  = go_vbox.find_child("NewRecordLabel",  true, false)
	go_score_value       = go_vbox.find_child("ScoreValue",      true, false)
	try_again_btn        = go_vbox.find_child("TryAgainBtn",     true, false)
	watch_ad_btn         = go_vbox.find_child("WatchAdBtn",      true, false)

	if play_btn:
		play_btn.pressed.connect(_start_game)
	
	if try_again_btn:
		try_again_btn.pressed.connect(_on_restart_pressed)
		
	if watch_ad_btn:
		watch_ad_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			AdManager.show_rewarded("game_over_continue")
		)
		
	var pause_vbox = $UILayer/PausePanel.get_node("VBox")
	var p_home_btn = pause_vbox.find_child("HomeBtn", true, false)
	if p_home_btn:
		p_home_btn.pressed.connect(_on_home_pressed)
		
	var p_set_btn = pause_vbox.find_child("SettingsBtn", true, false)
	if p_set_btn:
		p_set_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			pause_panel.hide()
			var set_panel = $UILayer.get_node_or_null("SettingsPanel")
			if set_panel: set_panel.show()
		)
		
	var go_home_btn = game_over_panel.get_node("VBox").find_child("HomeBtn", true, false)
	if go_home_btn:
		go_home_btn.pressed.connect(_on_home_pressed)
		
	# Best Score HUD
	_best_score_hud = Label.new()
	_best_score_hud.name = "BestScoreHUD"
	_best_score_hud.label_settings = UITheme.ls(16, UITheme.MUTED)
	_best_score_hud.text = "BEST: " + str(GameState.best_score)
	_best_score_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_best_score_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_best_score_hud.position = Vector2(VIEWPORT_W - 120, 100) # Below pause button
	$UILayer/HUD.add_child(_best_score_hud)
	
	# Streak Label
	_streak_label = Label.new()
	_streak_label.label_settings = UITheme.ls(20, UITheme.YELLOW)
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_streak_label.position.y = -150
	_streak_label.modulate.a = 0
	$UILayer.add_child(_streak_label)
		
	# Fever Overlay
	_fever_overlay = ColorRect.new()
	_fever_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fever_overlay.color = Color(1, 0, 0, 0)
	_fever_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(_fever_overlay)
	$UILayer.move_child(_fever_overlay, 0) # Behind UI
	
	_fever_label = Label.new()
	_fever_label.text = "CHAIN FEVER"
	_fever_label.label_settings = UITheme.ls(24, UITheme.MAGENTA)
	_fever_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fever_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fever_label.position.y = 120
	_fever_label.modulate.a = 0
	$UILayer.add_child(_fever_label)
		
	# Setup phase banner
	_phase_banner = Label.new()
	_phase_banner.name = "PhaseBanner"
	_phase_banner.label_settings = UITheme.ls(28, UITheme.CYAN)
	_phase_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_phase_banner.position.y = 200
	_phase_banner.modulate.a = 0
	$UILayer/HUD.add_child(_phase_banner)
		
	_show_menu()

func _show_phase_banner(phase_id: int, phase_name: String) -> void:
	if _state != State.PLAYING: return
	
	_phase_banner.text = "PHASE %d\n%s" % [phase_id, phase_name]
	
	if _phase_tween and _phase_tween.is_valid():
		_phase_tween.kill()
		
	_phase_tween = create_tween()
	_phase_tween.tween_property(_phase_banner, "modulate:a", 1.0, 0.4)
	_phase_tween.tween_interval(1.2)
	_phase_tween.tween_property(_phase_banner, "modulate:a", 0.0, 0.4)


# =====================================================
# GAME STATE TRANSITIONS
# =====================================================

func _show_menu() -> void:
	AudioManager.play(AudioManager.SND_BUTTON)
	AdManager.show_banner()
	_state = State.MENU
	if main_menu_panel:
		main_menu_panel.show()
	game_over_panel.hide()
	pause_panel.hide()
	$UILayer/HUD.hide()
	
	if is_instance_valid(_streak_label):
		_streak_label.modulate.a = 0
	if is_instance_valid(_fever_label):
		_fever_label.modulate.a = 0
	if is_instance_valid(_phase_banner):
		_phase_banner.modulate.a = 0
	if is_instance_valid(_fever_overlay):
		_fever_overlay.color.a = 0
		
	get_tree().paused = true
	player.reset(PLAYER_START)
	camera.reset()


func _start_game() -> void:
	AudioManager.play(AudioManager.SND_BUTTON)
	
	if tutorial_manager and not SaveManager.data.get("first_time_tutorial_completed", false):
		if main_menu_panel: main_menu_panel.hide()
		game_over_panel.hide()
		pause_panel.hide()
		$UILayer/HUD.hide()
		_state = State.PLAYING
		get_tree().paused = false
		player.reset(PLAYER_START)
		camera.reset()
		tutorial_manager.start_tutorial()
		return
		
	AdManager.show_banner()
	get_tree().paused = false
	platform_gen.clear_all()
	platform_gen.initialize(PLAYER_START, VIEWPORT_W)
	
	GameState.reset_for_new_game()
	_last_multiplier = 1
	_session_coins = 0
	_revive_used = false
	
	if ChallengeManager.is_active():
		_state = State.COUNTDOWN
		_setup_challenge_hud()
		_start_challenge_countdown()
	else:
		_state = State.PLAYING
		var chal_container = $UILayer/HUD.get_node_or_null("ChallengeContainer")
		if chal_container:
			chal_container.hide()
		
	GameEvents.run_started.emit()
	_update_hud()
	if main_menu_panel:
		main_menu_panel.hide()
	game_over_panel.hide()
	pause_panel.hide()
	$UILayer/HUD.show()
	player.reset(PLAYER_START)
	camera.reset()

func _restart_game() -> void:
	_start_game()


# =====================================================
# INPUT
# =====================================================

func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING:
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


# =====================================================
# MAIN PROCESS
# =====================================================

func _process(delta: float) -> void:
	if _state == State.PLAYING:
		# Update camera to follow player horizontally with some lag, and vertically
		var target_x = player.global_position.x
		var cam_x = lerp(camera.global_position.x, target_x, 5.0 * delta)
		camera.global_position.x = cam_x
		
		# Fever screen pulse
		if _fever_active:
			_fever_overlay.color = Color(1.0, 0.2, 0.2, 0.05 + sin(Time.get_ticks_msec() / 150.0) * 0.05)
			
		if ChallengeManager.is_active():
			_update_challenge_hud()

		if not (tutorial_manager and tutorial_manager.is_active()):
			platform_gen.update_generation(
				player.global_position.y,
				camera.global_position.y
			)

		var death_y: float = camera.get_bottom_world_y() + death_margin
		if player.global_position.y > death_y:
			if not (tutorial_manager and tutorial_manager.is_active()):
				GameEvents.run_completed.emit()
				_trigger_game_over()

	# Camera shake
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var shake_x = randf_range(-_shake_amount, _shake_amount)
		var shake_y = randf_range(-_shake_amount * 0.5, _shake_amount * 0.5)
		camera.offset = Vector2(shake_x, shake_y)
	else:
		camera.offset = Vector2.ZERO


# =====================================================
# LANDING — CHAIN + PERFECT + SCORE
# =====================================================

func _on_player_landed(platform_body: Node) -> void:
	if tutorial_manager and tutorial_manager.is_active():
		tutorial_manager.on_player_bounce(platform_body)
		return
		
	if _state != State.PLAYING:
		return

	# --- Landing Quality ---
	var grade: int = 2 # NORMAL
	var is_risk: bool = false
	var is_near: bool = false
	var is_perfect: bool = false
	
	if is_instance_valid(platform_body):
		if platform_body.has_method("claim_risk"):
			is_risk = platform_body.claim_risk()
			
		if platform_body.has_method("get_safe_center_x"):
			var safe_center: float = platform_body.get_safe_center_x()
			var safe_width: float = platform_body.get_safe_width()
			var dist = abs(player.global_position.x - safe_center)
			var ratio = dist / (safe_width * 0.5)
			
			if ratio <= 0.15:
				grade = 0 # PERFECT
				is_perfect = true
			elif ratio <= 0.35:
				grade = 1 # GOOD
			elif ratio <= 0.70:
				grade = 2 # NORMAL
			else:
				grade = 3 # NEAR
				is_near = true
	
	# --- Chain & Streak ---
	GameState.increment_chain()
	GameState.update_streak(grade)
	var chain = GameState.current_chain
	
	if grade == 0: GameState.perfect_count += 1
	elif grade == 3: GameState.near_count += 1
	
	if Engine.has_singleton("DifficultyManager"):
		DifficultyManager.record_landing(grade)

	# --- Score ---
	var gained: int = GameState.add_score_with_grade(grade)
	if is_risk:
		var risk_gain = GameState.add_score_with_grade(2) # Normal bonus extra
		gained += risk_gain
		
	_check_special_events(GameState.current_score)
	_update_hud()

	# --- Audio + Haptic ---
	if is_perfect:
		AudioManager.play(AudioManager.SND_PERFECT)
		AudioManager.vibrate_medium()
	else:
		AudioManager.play(AudioManager.SND_LAND)
		AudioManager.vibrate_light()

	# --- Feedback effects ---
	if is_perfect or is_near or is_risk or grade == 1:
		_show_landing_popup(grade, is_risk)
		if is_perfect:
			_camera_shake(4.0, 0.18)
			
	if GameState.current_streak > 2:
		_show_streak_popup()

	GameEvents.platform_landed.emit(is_perfect)

	# --- Coins ---
	var earned_coins = 0
	if is_perfect:
		earned_coins = 2
	else:
		earned_coins = 1

	# --- Chain animation ---
	_animate_chain_label()

	# --- Multiplier milestone check ---
	var new_mult: int = GameState.get_score_multiplier()
	if new_mult > _last_multiplier:
		_last_multiplier = new_mult
		_show_combo_milestone(new_mult)
		AudioManager.play(AudioManager.SND_COMBO)
		_camera_shake(6.0, 0.25)
		earned_coins += 5 # Milestone bonus
		
	# --- Chain Fever ---
	if chain == 20 and not _fever_active:
		_set_fever_state(true)
		
	# --- High Score Milestone / UI ---
	_update_best_score_hud()
		
	if earned_coins > 0 and not ChallengeManager.is_active():
		_session_coins += earned_coins
		CurrencyManager.add_coins(earned_coins)
		GameEvents.coins_earned.emit(earned_coins)
		_show_coin_popup(earned_coins)

func _set_fever_state(active: bool) -> void:
	if _fever_active == active: return
	_fever_active = active
	
	if _fever_active:
		AudioManager.play(AudioManager.SND_COMBO)
		var tween = create_tween()
		tween.tween_property(_fever_label, "modulate:a", 1.0, 0.5)
		tween.tween_property(_fever_label, "modulate:a", 0.0, 1.0).set_delay(2.0)
		player.modulate = Color(0.5, 1.5, 1.5) # Glowing cyan energy
	else:
		_fever_overlay.color = Color(0, 1, 1, 0)
		player.modulate = Color(1, 1, 1)

func _update_best_score_hud() -> void:
	if GameState.current_score > GameState.best_score and GameState.best_score > 0 and not GameState.new_score_record:
		GameState.new_score_record = true
		_show_floating_text("NEW BEST!", Color(1.0, 0.8, 0.2))
	if _best_score_hud:
		_best_score_hud.text = "BEST: " + str(max(GameState.current_score, GameState.best_score))

func _show_floating_text(text_str: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text_str
	var ls = LabelSettings.new()
	ls.font_size = 32
	ls.font_color = color
	ls.outline_size = 3
	ls.outline_color = Color(0, 0, 0, 0.9)
	lbl.label_settings = ls
	
	var screen_pos = get_viewport().get_canvas_transform() * player.global_position
	screen_pos.y -= 120.0
	screen_pos.x -= 50.0
	
	var hud = $UILayer/HUD
	hud.add_child(lbl)
	lbl.position = screen_pos
	
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", screen_pos.y - 80.0, 1.0)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(lbl.queue_free)

# =====================================================
# EVENT HANDLERS
# =====================================================

func _on_player_died() -> void:
	if tutorial_manager and tutorial_manager.is_active():
		return
		
	if _state != State.PLAYING:
		return
	
	if _fever_active:
		_show_floating_text(str(GameState.current_chain) + " CHAIN BROKEN", Color(1, 0, 0))
		_set_fever_state(false)
	
	# Route through _trigger_game_over so challenge mode (spike death → ChallengeFailedFlow)
	# is handled correctly, and the state guard inside prevents double-triggering.
	_state = State.PLAYING # reset so _trigger_game_over guard doesn't block it
	GameEvents.run_completed.emit()
	_trigger_game_over()
	
	# Update HUD labels after death
	if chain_label:
		chain_label.text = "CHAIN  x%d" % GameState.current_chain
	if multiplier_label:
		var m: int = GameState.get_score_multiplier()
		if m > 1:
			multiplier_label.text = "x%d COMBO" % m
			multiplier_label.show()
		else:
			multiplier_label.hide()


# =====================================================
# HUD UPDATE
# =====================================================

func _update_hud() -> void:
	score_label.text = str(GameState.current_score)
	if chain_label:
		chain_label.text = "CHAIN  x%d" % GameState.current_chain
	if multiplier_label:
		var m: int = GameState.get_score_multiplier()
		if m > 1:
			multiplier_label.text = "x%d COMBO" % m
			multiplier_label.show()
		else:
			multiplier_label.hide()


func _animate_chain_label() -> void:
	if not chain_label:
		return
	var tween = create_tween()
	tween.tween_property(chain_label, "scale", Vector2(1.35, 1.35), 0.10)
	tween.tween_property(chain_label, "scale", Vector2(1.0, 1.0), 0.10)


# =====================================================
# PERFECT LANDING POPUP
# =====================================================

func _show_landing_popup(grade: int, is_risk: bool) -> void:
	var lbl = Label.new()
	var text_str = ""
	var color = Color.WHITE
	
	if grade == 0:
		text_str = "PERFECT!"
		color = Color(1.0, 0.4, 0.8) # Magenta
	elif grade == 1:
		text_str = "GOOD"
		color = Color(0.4, 0.8, 1.0) # Cyan
	elif grade == 3:
		text_str = "NEAR!"
		color = Color(1.0, 0.6, 0.2) # Orange
		
	if is_risk:
		text_str += "\n2X RISK"
		if grade == 2: # Normal
			color = Color(1.0, 0.8, 0.2)
			
	lbl.text = text_str
	var ls = LabelSettings.new()
	ls.font_size = 48
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * player.global_position
	screen_pos.y -= 80.0
	screen_pos.x -= 80.0
	
	ls.font_color = color
	ls.shadow_color = Color(1.0, 0.5, 0.0, 0.8)
	ls.shadow_size = 6
	ls.outline_size = 3
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	lbl.label_settings = ls

	var hud: Control = $UILayer/HUD
	hud.add_child(lbl)
	lbl.position = screen_pos

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", screen_pos.y - 100.0, 0.7)
	tween.tween_property(lbl, "scale",      Vector2(1.4, 1.4), 0.15)
	tween.chain().tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(lbl.queue_free)

func _show_streak_popup() -> void:
	if not _streak_label: return
	_streak_label.text = "STREAK x" + str(GameState.current_streak)
	if _streak_tween and _streak_tween.is_valid():
		_streak_tween.kill()
	_streak_tween = create_tween().bind_node(self)
	_streak_label.modulate.a = 1.0
	_streak_label.scale = Vector2(1.2, 1.2)
	_streak_tween.tween_property(_streak_label, "scale", Vector2(1.0, 1.0), 0.2)
	_streak_tween.tween_property(_streak_label, "modulate:a", 0.0, 0.5).set_delay(1.5)


# =====================================================
# COIN POPUP
# =====================================================

func _show_coin_popup(amount: int) -> void:
	var lbl = Label.new()
	lbl.text = "+%d" % amount
	var ls = LabelSettings.new()
	ls.font_size = 32
	ls.font_color = Color(1.0, 0.82, 0.1, 1.0) # Yellow
	ls.outline_size = 2
	ls.outline_color = Color(0, 0, 0, 0.8)
	lbl.label_settings = ls
	
	# Position near coin counter (top left)
	# Assuming coin counter is around (130, 40)
	var start_pos = Vector2(140.0, 40.0)
	lbl.position = start_pos
	
	var hud: Control = $UILayer/HUD
	hud.add_child(lbl)
	
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", start_pos.y - 40.0, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tween.chain().tween_callback(lbl.queue_free)


# =====================================================
# DAILY / MISSION POPUPS
# =====================================================

func _on_daily_completed() -> void:
	_show_notification_popup("DAILY CHALLENGE COMPLETE!", Color(1.0, 0.82, 0.12, 1.0))
	AudioManager.play(AudioManager.SND_COMBO)

func _check_special_events(score: int) -> void:
	var new_event = ""
	if score >= 20000: new_event = "CHAOS MODE"
	elif score >= 15000: new_event = "OVERDRIVE"
	elif score >= 10000: new_event = "NEON RUSH"
	elif score >= 5000: new_event = "CYBER STORM"
	
	if new_event != "" and new_event != GameState.highest_event:
		GameState.highest_event = new_event
		_show_notification_popup("WORLD EVENT\n" + new_event, Color(1.0, 0.4, 0.4))
		AudioManager.play(AudioManager.SND_COMBO)
		_camera_shake(5.0, 0.3)
		# Add a quick white flash overlay
		var flash = ColorRect.new()
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.color = Color(1.0, 1.0, 1.0, 1.0)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$UILayer.add_child(flash)
		var t = create_tween()
		t.tween_property(flash, "modulate:a", 0.0, 0.5)
		t.chain().tween_callback(flash.queue_free)

func _on_mission_completed(index: int) -> void:
	_show_notification_popup("MISSION COMPLETE!", Color(0.0, 0.9, 1.0, 1.0))
	AudioManager.play(AudioManager.SND_COMBO)

func _show_notification_popup(text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	var ls = LabelSettings.new()
	ls.font_size = 32
	ls.font_color = color
	ls.outline_size = 4
	ls.outline_color = Color.BLACK
	ls.shadow_color = Color(color, 0.6)
	ls.shadow_size = 8
	lbl.label_settings = ls
	
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hud: Control = $UILayer/HUD
	hud.add_child(lbl)
	
	# Center top screen
	var start_pos = Vector2(540/2 - 200, 120.0) # approx center
	lbl.size = Vector2(400, 50)
	lbl.position = start_pos
	lbl.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tween.tween_property(lbl, "position:y", start_pos.y - 30.0, 2.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(lbl.queue_free)


# =====================================================
# COMBO MILESTONE POPUP
# =====================================================

func _show_combo_milestone(multiplier: int) -> void:
	var lbl = Label.new()
	lbl.text = "COMBO x%d!" % multiplier
	var ls = LabelSettings.new()
	ls.font_size = 52
	ls.font_color = Color(1.0, 0.82, 0.1, 1.0)
	ls.shadow_color = Color(1.0, 0.3, 0.0, 0.8)
	ls.shadow_size = 8
	ls.outline_size = 3
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	lbl.label_settings = ls
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * player.global_position
	screen_pos.y -= 140.0
	screen_pos.x -= 100.0

	var hud: Control = $UILayer/HUD
	hud.add_child(lbl)
	lbl.position = screen_pos

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "scale", Vector2(1.6, 1.6), 0.12)
	tween.chain().tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.12)
	tween.tween_property(lbl, "position:y", screen_pos.y - 80.0, 0.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.chain().tween_callback(lbl.queue_free)


# =====================================================
# CAMERA SHAKE
# =====================================================

func _camera_shake(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_timer = duration


# =====================================================
# GAME OVER
# =====================================================


func _trigger_game_over() -> void:
	if _state == State.GAME_OVER:
		return
		
	if ChallengeManager.is_active():
		player.die()
		_challenge_failed_flow()
		return
		
	_state = State.GAME_OVER
	player.die()
	GameState.finalize_records()
	
	if (GameState.new_score_record or GameState.new_chain_record) and not ChallengeManager.is_active():
		# Reward for new personal bests
		_session_coins += 10
		CurrencyManager.add_coins(10)
		GameEvents.coins_earned.emit(10)
			
	AudioManager.play(AudioManager.SND_GAMEOVER)
	_show_game_over_screen()

func _on_restart_pressed() -> void:
	AudioManager.play(AudioManager.SND_BUTTON)
	
	if ChallengeManager.is_active():
		var chal = ChallengeManager.get_active_challenge()
		var fee = ChallengeManager.get_effective_entry_fee(chal.id)
		if fee > 0:
			if not CurrencyManager.can_afford(fee):
				pause_panel.hide()
				_cleanup_challenge_and_go_home(null)
				return
			CurrencyManager.spend_coins(fee)

	get_tree().paused = false
	if _state == State.GAME_OVER:
		AdManager.record_run_completed()
		if AdManager.should_show_interstitial():
			_pending_interstitial_action = "restart"
			AdManager.show_interstitial()
			return
	_restart_game()

func _on_home_pressed() -> void:
	AudioManager.play(AudioManager.SND_BUTTON)
	pause_panel.hide()
	get_tree().paused = false
	if AdManager.should_show_interstitial():
		_pending_interstitial_action = "home"
		AdManager.show_interstitial()
		return
	_show_menu()

func _on_score_changed(new_score: int, _amt: int) -> void:
	if _last_tracked_score < 1000 and new_score >= 1000:
		if not ChallengeManager.is_active():
			_show_challenge_starts()
	_last_tracked_score = new_score
	
	if ChallengeManager.is_active() and _state == State.PLAYING:
		var chal = ChallengeManager.get_active_challenge()
		if new_score >= chal.target:
			_trigger_challenge_success()

func _show_challenge_starts() -> void:
	AudioManager.play(AudioManager.SND_EQUIP) # Use existing positive/intense sound
	
	# Spawn a temporary label
	var lbl = Label.new()
	lbl.text = "CHALLENGE STARTS"
	lbl.label_settings = UITheme.ls_title_font(32, UITheme.MAGENTA)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Add to HUD layer so it shows over gameplay but under menus
	var hud = $UILayer/HUD
	hud.add_child(lbl)
	
	# Center it on screen
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position.y -= 100 # Slightly above center
	
	# Visual intensity increase
	if is_instance_valid(background) and background.has_method("set_glow_intensity"):
		# Assuming background can be intensified. If not, just ignore or manually tweak modulate
		var grid = background.get_node_or_null("Grid")
		if grid:
			var tw_bg = create_tween()
			tw_bg.tween_property(grid, "modulate:a", grid.modulate.a * 1.5, 0.5)
	
	# Animate the label
	lbl.scale = Vector2(0.5, 0.5)
	lbl.modulate.a = 0.0
	
	var tw = create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(0.8)
	tw.tween_property(lbl, "position:y", lbl.position.y - 50, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)

func _on_interstitial_closed() -> void:
	if _pending_interstitial_action == "restart":
		_restart_game()
	elif _pending_interstitial_action == "home":
		_show_menu()
	_pending_interstitial_action = ""

func _on_rewarded_ad_completed(reward_id: String) -> void:
	if reward_id.begins_with("free_tier_"):
		var tier = reward_id.replace("free_tier_", "")
		var prog = SaveManager.data.get("free_coins_progress", {"50": 0, "100": 0, "200": 0, "500": 0, "1000": 0})
		var curr = prog.get(tier, 0)
		var req = 1
		if tier == "100": req = 2
		elif tier == "200": req = 3
		elif tier == "500": req = 4
		elif tier == "1000": req = 5
		
		curr += 1
		if curr >= req:
			CurrencyManager.add_coins(int(tier))
			prog[tier] = 0
			var today = Time.get_date_string_from_system()
			if SaveManager.data.get("free_coins_date", "") != today:
				SaveManager.data["free_coins_date"] = today
				SaveManager.data["free_coins_claimed"] = []
			var claimed = SaveManager.data.get("free_coins_claimed", [])
			if not tier in claimed:
				claimed.append(tier)
			SaveManager.data["free_coins_claimed"] = claimed
		else:
			prog[tier] = curr
			
		SaveManager.data["free_coins_progress"] = prog
		SaveManager.save_data()
		
		var bldr = $UILayer
		if bldr and bldr.has_method("refresh_free_coins_ui"):
			bldr.refresh_free_coins_ui()
		return
		
	if reward_id == "game_over_continue":
		_continue_game()
	elif reward_id == "challenge_continue":
		_continue_challenge()
	elif reward_id == "free_coins_100":
		CurrencyManager.add_coins(100)
		SaveManager.data["ad_free_coin_time"] = Time.get_unix_time_from_system()
		SaveManager.save_data()
		
		# Teardown the ad popup if it's currently open
		var chal_ui = $UILayer/ChallengesUI
		if chal_ui:
			var popup = chal_ui.get_node_or_null("NotEnoughCoinsBG")
			if popup: popup.queue_free()
			if chal_ui.visible and chal_ui.has_method("_refresh_ui"):
				chal_ui._refresh_ui()
				
		var shop_ui = $UILayer/ShopPanel
		if shop_ui:
			var popup = shop_ui.get_node_or_null("NotEnoughCoinsBG")
			if popup: popup.queue_free()
			if shop_ui.visible and shop_ui.has_method("_refresh_all_cards"):
				shop_ui._refresh_all_cards()
				
	elif reward_id == "daily_2x":
		DailyChallengeManager.claim_reward(2)
	elif reward_id.begins_with("mission_2x_"):
		var idx = reward_id.trim_prefix("mission_2x_").to_int()
		MissionManager.claim_reward(idx, 2)
	elif reward_id == "challenge_2x":
		var chal = ChallengeManager.get_active_challenge()
		if not chal.is_empty():
			CurrencyManager.add_coins(chal.reward * 2)
			_finish_challenge_flow_from_ad()

func _on_rewarded_ad_failed(reward_id: String) -> void:
	if reward_id == "game_over_continue":
		var continue_btn = game_over_panel.get_node_or_null("VBox/ContinueBtn")
		if continue_btn:
			var original_text = continue_btn.text
			continue_btn.text = "Loading Ad... Try again!"
			await get_tree().create_timer(2.0).timeout
			if is_instance_valid(continue_btn):
				continue_btn.text = original_text
	elif reward_id == "challenge_continue":
		var bg = $UILayer.get_node_or_null("ChallengeFailBG")
		if bg:
			var center = bg.get_child(0)
			if center:
				var pnl = center.get_child(0)
				if pnl:
					var vbox = pnl.get_child(0)
					if vbox:
						# Find the button (it should be the 3rd child, but let's iterate safely)
						for child in vbox.get_children():
							if child is Button and "WATCH AD" in child.text:
								var original_text = child.text
								child.text = "Loading Ad... Try again!"
								await get_tree().create_timer(2.0).timeout
								if is_instance_valid(child):
									child.text = original_text

func _continue_game() -> void:
	_revive_used = true
	_state = State.PLAYING
	game_over_panel.hide()
	$UILayer/HUD.show()
	get_tree().paused = false
	
	player.is_alive = true
	player.move_direction = 0.0
	player.revive()
	_apply_safe_revive()

func _continue_challenge() -> void:
	_revive_used = true
	for child in $UILayer.get_children():
		if child.name == "ChallengeFailBG":
			child.queue_free()
	# Revive player BEFORE changing state to PLAYING so _process never sees
	# is_alive=false with state=PLAYING (which would instantly re-trigger game over)
	player.is_alive = true
	player.move_direction = 0.0
	player.velocity = Vector2.ZERO
	ChallengeManager.revive_challenge(15.0)
	_state = State.PLAYING
	get_tree().paused = false
	_apply_safe_revive()

func _apply_safe_revive() -> void:
	platform_gen.clear_all()
	player.platform_scored.clear()
	var safe_y = camera.global_position.y - 100.0
	player.global_position = Vector2(VIEWPORT_W * 0.5, safe_y - 60.0)
	player.velocity = Vector2.ZERO
	player.velocity.y = player.bounce_force
	platform_gen.spawn_safe_platform(safe_y, 260.0)

func _finish_challenge_flow_from_ad() -> void:
	var bg = $UILayer.get_node_or_null("ChallengeSuccessBG")
	_cleanup_challenge_and_go_home(bg)
	
func _show_game_over_screen() -> void:
	# Fill in score values
	go_score_value.text = str(GameState.current_score)

	if go_best_score_value:
		go_best_score_value.text = str(GameState.best_score)
	if go_chain_value:
		go_chain_value.text = str(GameState.current_chain)
	if go_best_chain_value:
		go_best_chain_value.text = str(GameState.best_chain)
		
		
	# Clean up any leftover RunSummary nodes if they somehow persist
	var go_vbox = game_over_panel.get_node_or_null("VBox")
	if go_vbox:
		for child in go_vbox.get_children():
			if child.name.begins_with("RunSummary"):
				go_vbox.remove_child(child)
				child.queue_free()


	if player.death_reason != "":
		# We can repurpose go_new_record_label or just use it to show the death reason temporarily
		if not go_new_record_label:
			pass # ui_builder didn't create it
		elif go_new_record_label.text == "":
			go_new_record_label.text = player.death_reason
			go_new_record_label.label_settings.font_color = Color(1.0, 0.2, 0.2)
			go_new_record_label.show()

	# New record label
	if go_new_record_label:
		if GameState.new_score_record or GameState.new_chain_record:
			var txt = ""
			if GameState.new_score_record and GameState.new_chain_record:
				txt = "NEW RECORD & CHAIN RECORD!"
			elif GameState.new_score_record:
				txt = "NEW SCORE RECORD!"
			else:
				txt = "NEW CHAIN RECORD!"
			go_new_record_label.text = txt
			go_new_record_label.show()
			_animate_new_record_label()
		else:
			if player.death_reason == "":
				go_new_record_label.hide()
			else:
				go_new_record_label.text = player.death_reason
				go_new_record_label.label_settings.font_color = Color(1.0, 0.2, 0.2)
				go_new_record_label.show()
			
	# Update Coin Labels (use find_child because they're inside HBox wrappers)
	var go_vbox2 = game_over_panel.get_node_or_null("VBox")
	if go_vbox2:
		var coins_earned_lbl = go_vbox2.find_child("CoinsEarnedValue", true, false)
		if coins_earned_lbl:
			coins_earned_lbl.text = "+%d" % _session_coins
		
		var total_coins_lbl = go_vbox2.find_child("TotalCoinsValue", true, false)
		if total_coins_lbl:
			total_coins_lbl.text = str(CurrencyManager.get_coins())

	if watch_ad_btn:
		watch_ad_btn.visible = not _revive_used

	game_over_panel.show()


func _animate_new_record_label() -> void:
	if not go_new_record_label:
		return
	var tween = create_tween()
	tween.tween_property(go_new_record_label, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(go_new_record_label, "scale", Vector2(1.0, 1.0), 0.15)


# =====================================================
# PAUSE
# =====================================================

func _on_pause_pressed() -> void:
	AudioManager.play(AudioManager.SND_PAUSE)
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	pause_panel.show()
	get_tree().paused = true
	if ChallengeManager.is_active():
		ChallengeManager.pause_challenge()

func _on_resume_pressed() -> void:
	AudioManager.play(AudioManager.SND_PAUSE)
	pause_panel.hide()
	get_tree().paused = false
	_state = State.PLAYING
	if ChallengeManager.is_active():
		ChallengeManager.resume_challenge()
	get_tree().paused = false
	_state = State.PLAYING
	pause_panel.hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var chal_bg = $UILayer.get_node_or_null("ChallengeSuccessBG")
		if chal_bg: return
		
		var bldr = $UILayer
		
		var set_panel = bldr.get_node_or_null("SettingsPanel")
		if set_panel and set_panel.visible:
			var about_panel = set_panel.get_node_or_null("VBox/AboutPanel")
			if about_panel and about_panel.visible:
				about_panel.hide()
			else:
				set_panel.hide()
				if _state == State.MENU:
					main_menu_panel.show()
				elif _state == State.PAUSED:
					pause_panel.show()
			return

		var panels = ["ShopPanel", "DailyPanel", "MissionsPanel", "ChallengesPanel", "FreeCoinsPanel"]
		for p_name in panels:
			var p = bldr.get_node_or_null(p_name)
			if p and p.visible:
				if p_name == "ChallengesPanel":
					var no_c = p.get_node_or_null("NotEnoughCoinsBG")
					if no_c and no_c.visible:
						no_c.queue_free()
						return
				p.hide()
				main_menu_panel.show()
				return

		if _state == State.PLAYING:
			_on_pause_pressed()
		elif _state == State.PAUSED:
			_on_resume_pressed()
		elif _state == State.GAME_OVER:
			_on_home_pressed()
		elif _state == State.MENU:
			get_tree().quit()

	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if _state == State.PLAYING:
			_on_pause_pressed()
			
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		pass

# =====================================================
# CHALLENGE MODE SPECIFIC FLOW
# =====================================================

func _setup_challenge_hud() -> void:
	var hud = $UILayer/HUD
	# Find or create Challenge Container
	var chal_container = hud.get_node_or_null("ChallengeContainer")
	if not chal_container:
		chal_container = VBoxContainer.new()
		chal_container.name = "ChallengeContainer"
		chal_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		chal_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		chal_container.offset_right = -20
		chal_container.offset_top = 120
		hud.add_child(chal_container)
		
		_chal_timer_lbl = Label.new()
		_chal_timer_lbl.label_settings = UITheme.ls_title_font(32, UITheme.YELLOW)
		_chal_timer_lbl.text = "00:00.0"
		_chal_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chal_container.add_child(_chal_timer_lbl)
		
		_chal_target_lbl = Label.new()
		_chal_target_lbl.label_settings = UITheme.ls(16, UITheme.CYAN)
		_chal_target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chal_container.add_child(_chal_target_lbl)
		
		_chal_progress_bar = ProgressBar.new()
		_chal_progress_bar.custom_minimum_size = Vector2(160, 8)
		_chal_progress_bar.show_percentage = false
		var sb_bg = StyleBoxFlat.new()
		sb_bg.bg_color = UITheme.SURFACE
		sb_bg.set_corner_radius_all(4)
		var sb_fg = StyleBoxFlat.new()
		sb_fg.bg_color = UITheme.CYAN
		sb_fg.set_corner_radius_all(4)
		_chal_progress_bar.add_theme_stylebox_override("background", sb_bg)
		_chal_progress_bar.add_theme_stylebox_override("fill", sb_fg)
		chal_container.add_child(_chal_progress_bar)
		
		_chal_progress_lbl = Label.new()
		_chal_progress_lbl.label_settings = UITheme.ls(14, UITheme.WHITE)
		chal_container.add_child(_chal_progress_lbl)
	else:
		chal_container.show()
	
	if not ChallengeManager.time_updated.is_connected(_on_challenge_time_updated):
		ChallengeManager.time_updated.connect(_on_challenge_time_updated)
	if not ChallengeManager.state_changed.is_connected(_on_challenge_state_changed):
		ChallengeManager.state_changed.connect(_on_challenge_state_changed)

func _update_challenge_hud() -> void:
	if not is_instance_valid(_chal_target_lbl): return
	var chal = ChallengeManager.get_active_challenge()
	if chal.is_empty(): return
	
	var cur = GameState.current_score
	var tgt = chal.target
	_chal_target_lbl.text = "TARGET: %d" % tgt
	
	var pct = minf(float(cur) / float(tgt) * 100.0, 100.0)
	_chal_progress_bar.value = pct
	_chal_progress_lbl.text = "%d / %d (%d%%)" % [cur, tgt, int(pct)]

func _on_challenge_time_updated(time_left: float) -> void:
	if not is_instance_valid(_chal_timer_lbl): return
	var chal = ChallengeManager.get_active_challenge()
	if chal.is_empty(): return
	
	var m = int(time_left) / 60
	var s = int(time_left) % 60
	var ms = int((time_left - floor(time_left)) * 10.0)
	_chal_timer_lbl.text = "%02d:%02d.%1d" % [m, s, ms]
	
	var pct = time_left / chal.time
	if pct > 0.3:
		_chal_timer_lbl.label_settings.font_color = UITheme.YELLOW
	elif pct > 0.1:
		_chal_timer_lbl.label_settings.font_color = Color(1.0, 0.5, 0.0) # Orange
	else:
		_chal_timer_lbl.label_settings.font_color = UITheme.MAGENTA

func _on_challenge_state_changed(new_state: int) -> void:
	if new_state == ChallengeManager.State.FAILED:
		_challenge_failed_flow()

func _start_challenge_countdown() -> void:
	# Spawn blocking overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UILayer.add_child(overlay)
	
	var lbl = Label.new()
	lbl.text = "3"
	lbl.label_settings = UITheme.ls_title_font(100, UITheme.CYAN)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(lbl)
	
	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		AudioManager.play(AudioManager.SND_EQUIP)
		lbl.text = "2"
	)
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		AudioManager.play(AudioManager.SND_EQUIP)
		lbl.text = "1"
	)
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		AudioManager.play(AudioManager.SND_COMBO)
		lbl.text = "GO!"
		lbl.label_settings.font_color = UITheme.GOLD
		ChallengeManager.begin_running()
		_state = State.PLAYING
	)
	tw.tween_interval(0.5)
	tw.tween_callback(overlay.queue_free)

func _trigger_challenge_success() -> void:
	if _state == State.GAME_OVER:
		return
	_state = State.GAME_OVER # Block inputs
	ChallengeManager.complete_challenge()
	get_tree().paused = true
	
	AudioManager.play(AudioManager.SND_COMBO)
	
	var chal = ChallengeManager.get_active_challenge()
	var comp = ChallengeManager.record_challenge_completion(chal.id, GameState.current_score, ChallengeManager.time_left)
	
	# Spawn custom success screen over everything
	var bg = ColorRect.new()
	bg.name = "ChallengeSuccessBG"
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	$UILayer.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	
	var pnl = PanelContainer.new()
	var sb = UITheme.glass_panel_challenges(UITheme.CYAN, 16)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	pnl.add_child(vbox)
	
	var lbl1 = Label.new()
	lbl1.text = "CHALLENGE COMPLETE"
	lbl1.label_settings = UITheme.ls_title_font(28, UITheme.GOLD)
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl1)
	
	var score_lbl = Label.new()
	score_lbl.text = "SCORE: %d
TARGET: %d" % [GameState.current_score, chal.target]
	score_lbl.label_settings = UITheme.ls(20, UITheme.WHITE)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)
	
	var time_lbl = Label.new()
	time_lbl.text = "TIME LEFT: %d.%d" % [int(ChallengeManager.time_left), int((ChallengeManager.time_left - floor(ChallengeManager.time_left)) * 10)]
	time_lbl.label_settings = UITheme.ls(20, UITheme.CYAN)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(time_lbl)
	
	var rank = ChallengeManager.get_rank_by_id(chal.rank)
	var required_stars = comp.get("required_stars", rank.required_stars)
	var old_stars = comp.get("old_stars", 0)
	var stars_earned = comp.stars_earned
	
	var stars_container = VBoxContainer.new()
	stars_container.add_theme_constant_override("separation", 4)
	vbox.add_child(stars_container)
	
	var star_icons_hbox = HBoxContainer.new()
	star_icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.add_child(star_icons_hbox)
	
	var star_labels = []
	for i in range(required_stars):
		var s_lbl = Label.new()
		s_lbl.pivot_offset = Vector2(21, 21)
		if i < old_stars:
			s_lbl.text = "★"
			s_lbl.label_settings = UITheme.ls_glow_title(42, rank.color, rank.color)
		else:
			s_lbl.text = "☆"
			s_lbl.label_settings = UITheme.ls_title_font(42, Color(0.3, 0.3, 0.3))
		star_icons_hbox.add_child(s_lbl)
		star_labels.append(s_lbl)
		
	var star_count_lbl = Label.new()
	star_count_lbl.text = "%d / %d STARS" % [old_stars, required_stars]
	star_count_lbl.label_settings = UITheme.ls(16, UITheme.MUTED)
	star_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_container.add_child(star_count_lbl)
	
	var info_lbl = Label.new()
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if stars_earned == 0:
		info_lbl.text = "ALREADY COMPLETED\nNO NEW STARS EARNED"
		info_lbl.label_settings = UITheme.ls(16, UITheme.MUTED)
	else:
		info_lbl.text = "STAR EARNED!"
		info_lbl.label_settings = UITheme.ls_glow_title(24, UITheme.GOLD, UITheme.GOLD)
		info_lbl.hide() # hide until animated
	
	if comp.is_new_best:
		info_lbl.text += "\n(NEW PERSONAL BEST!)"
		info_lbl.label_settings = UITheme.ls_glow_title(24, UITheme.CYAN, UITheme.CYAN)
	vbox.add_child(info_lbl)
	
	var rank_lbl = Label.new()
	rank_lbl.text = "CURRENT RANK: " + rank.name
	rank_lbl.label_settings = UITheme.ls_glow_title(18, rank.color, rank.color)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rank_lbl)
	
	var finish_flow = func():
		bg.queue_free()
		if comp.newly_unlocked_rank:
			_show_rank_up(rank, comp.newly_unlocked_rank)
		else:
			_cleanup_challenge_and_go_home(bg)
			
	var btn_vbox = VBoxContainer.new()
	btn_vbox.hide()
	vbox.add_child(btn_vbox)
	
	var claim_btn = UITheme.make_filled_button("CLAIM REWARD\n+%d COINS" % chal.reward, UITheme.GOLD)
	var _star_reward_processed = false
	claim_btn.pressed.connect(func():
		if _star_reward_processed: return
		_star_reward_processed = true
		AudioManager.play(AudioManager.SND_BUTTON)
		CurrencyManager.add_coins(chal.reward)
		finish_flow.call()
	)
	btn_vbox.add_child(claim_btn)
	
	var ad_btn = UITheme.make_filled_button("WATCH AD\n2X REWARD", UITheme.MAGENTA)
	ad_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		AdManager.show_rewarded("challenge_2x")
	)
	btn_vbox.add_child(ad_btn)
	
	# --- ANIMATION LOGIC ---
	if stars_earned == 0:
		btn_vbox.show()
		info_lbl.show()
	else:
		var overlay = Control.new()
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.add_child(overlay)
		
		# Darken effect behind star
		var dim = ColorRect.new()
		dim.color = Color(0,0,0,0)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.add_child(dim)
		
		var tw = create_tween().bind_node(bg)
		tw.tween_interval(0.5)
		tw.tween_property(dim, "color:a", 0.6, 0.3)
		tw.tween_callback(info_lbl.show)
		
		var current_old = old_stars
		
		for i in range(stars_earned):
			var idx = current_old + i
			if idx >= required_stars:
				break
				
			var fly_star = Label.new()
			fly_star.text = "★"
			fly_star.label_settings = UITheme.ls_glow_title(80, rank.color, Color.WHITE)
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			fly_star.material = mat
			fly_star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fly_star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fly_star.modulate.a = 0
			fly_star.scale = Vector2(0.2, 0.2)
			fly_star.pivot_offset = Vector2(40, 40)
			
			tw.tween_callback(func():
				overlay.add_child(fly_star)
				var vp_size = get_viewport_rect().size
				fly_star.position = Vector2(vp_size.x/2.0 - 40, vp_size.y/2.0 - 60)
				AudioManager.play(AudioManager.SND_REWARD)
				if SettingsManager.vibration_enabled:
					Input.vibrate_handheld(50)
			)
			
			tw.tween_property(fly_star, "modulate:a", 1.0, 0.1)
			tw.parallel().tween_property(fly_star, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(fly_star, "rotation", deg_to_rad(180), 0.2)
			tw.tween_property(fly_star, "scale", Vector2(1.0, 1.0), 0.1)
			tw.parallel().tween_property(fly_star, "rotation", deg_to_rad(360), 0.1)
			tw.tween_interval(0.3)
			
			# Fly to slot
			tw.tween_callback(func():
				var target_slot = star_labels[idx]
				var gpos = target_slot.get_global_position()
				var fly_tw = create_tween().bind_node(bg)
				fly_tw.tween_property(fly_star, "global_position", gpos - Vector2(19, 19), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				fly_tw.parallel().tween_property(fly_star, "scale", Vector2(0.6, 0.6), 0.4)
				fly_tw.parallel().tween_property(fly_star, "rotation", fly_star.rotation + TAU*2, 0.4)
				fly_tw.tween_callback(func():
					fly_star.queue_free()
					target_slot.text = "★"
					target_slot.label_settings = UITheme.ls_glow_title(42, rank.color, rank.color)
					target_slot.scale = Vector2(1.8, 1.8)
					
					var slot_tw = create_tween().bind_node(bg)
					slot_tw.tween_property(target_slot, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE)
					
					var blast = Label.new()
					blast.text = "★"
					blast.label_settings = UITheme.ls_glow_title(42, Color.WHITE, rank.color)
					blast.material = mat
					blast.position = target_slot.get_global_position()
					blast.pivot_offset = Vector2(21, 21)
					bg.add_child(blast)
					
					var blast_tw = create_tween().bind_node(bg)
					blast_tw.tween_property(blast, "scale", Vector2(2.5, 2.5), 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
					blast_tw.parallel().tween_property(blast, "modulate:a", 0.0, 0.4)
					blast_tw.tween_callback(blast.queue_free)
					
					var new_val = current_old + i + 1
					star_count_lbl.text = "%d / %d STARS" % [new_val, required_stars]
					star_count_lbl.scale = Vector2(1.2, 1.2)
					star_count_lbl.label_settings.font_color = UITheme.WHITE
					
					var num_tw = create_tween().bind_node(bg)
					num_tw.tween_property(star_count_lbl, "scale", Vector2(1.0, 1.0), 0.2)
					num_tw.parallel().tween_property(star_count_lbl.label_settings, "font_color", UITheme.MUTED, 0.5)
					
					# Light particles
					for p in 12:
						var part = ColorRect.new()
						part.color = Color.WHITE
						part.size = Vector2(5, 5)
						part.position = target_slot.get_global_position() + Vector2(21, 21)
						bg.add_child(part)
						var p_tw = create_tween().bind_node(bg)
						var angle = randf() * TAU
						var dist = randf_range(30, 80)
						p_tw.tween_property(part, "position", part.position + Vector2(cos(angle), sin(angle))*dist, 0.5).set_ease(Tween.EASE_OUT)
						p_tw.parallel().tween_property(part, "color:a", 0.0, 0.5)
						p_tw.parallel().tween_property(part, "rotation", TAU, 0.5)
						p_tw.tween_callback(part.queue_free)
				)
			)
			tw.tween_interval(0.4)
			
		tw.tween_property(dim, "color:a", 0.0, 0.2)
		tw.tween_callback(func():
			overlay.queue_free()
			
			if comp.rank_up:
				if SettingsManager.vibration_enabled:
					Input.vibrate_handheld(100)
				var ru_lbl = Label.new()
				ru_lbl.text = "RANK COMPLETE!"
				ru_lbl.label_settings = UITheme.ls_glow_title(28, UITheme.GOLD, UITheme.GOLD)
				ru_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ru_lbl.modulate.a = 0
				vbox.add_child(ru_lbl)
				vbox.move_child(ru_lbl, stars_container.get_index() + 1)
				
				var ru_tw = create_tween().bind_node(bg)
				ru_tw.tween_property(ru_lbl, "modulate:a", 1.0, 0.3)
				ru_tw.tween_interval(0.5)
				ru_tw.tween_callback(btn_vbox.show)
			else:
				btn_vbox.show()
		)

func _challenge_failed_flow() -> void:
	if _state == State.GAME_OVER:
		return
	_state = State.GAME_OVER
	get_tree().paused = true
	
	AudioManager.play(AudioManager.SND_GAMEOVER)
	var chal = ChallengeManager.get_active_challenge()
	
	var bg = ColorRect.new()
	bg.name = "ChallengeFailBG"
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	$UILayer.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	
	var pnl = PanelContainer.new()
	var sb = UITheme.glass_panel_challenges(UITheme.MAGENTA, 16)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	pnl.add_child(vbox)
	
	var lbl1 = Label.new()
	lbl1.text = "CHALLENGE FAILED"
	lbl1.label_settings = UITheme.ls_title_font(28, UITheme.MAGENTA)
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl1)
	
	var short_by = chal.target - GameState.current_score
	
	var score_lbl = Label.new()
	score_lbl.text = "SCORE: %d\nTARGET: %d\nSHORT BY: %d" % [GameState.current_score, chal.target, short_by]
	score_lbl.label_settings = UITheme.ls(20, UITheme.WHITE)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)
	
	if not _revive_used:
		var revive_btn = UITheme.make_filled_button("WATCH AD\nCONTINUE", UITheme.GOLD)
		revive_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			AdManager.show_rewarded("challenge_continue")
		)
		vbox.add_child(revive_btn)
	
	var try_btn = UITheme.make_filled_button("TRY AGAIN", UITheme.CYAN)
	try_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		bg.queue_free()
		ChallengeManager.cleanup_challenge()
		# Unpause BEFORE attempting start in case it fails and leaves us stuck
		get_tree().paused = false
		# Re-launch
		var chal_panel = get_node_or_null("UILayer/ChallengesPanel")
		if chal_panel:
			chal_panel._attempt_start(chal.id)
			if not ChallengeManager.is_active():
				_show_menu() # It failed to start (e.g. no coins), fallback to menu
		else:
			_show_menu()
	)
	vbox.add_child(try_btn)
	
	var home_btn = UITheme.make_button("HOME", UITheme.MUTED)
	home_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		_cleanup_challenge_and_go_home(bg)
	)
	vbox.add_child(home_btn)

func _cleanup_challenge_and_go_home(bg_overlay: Node) -> void:
	if bg_overlay:
		bg_overlay.queue_free()
	var chal_container = $UILayer/HUD.get_node_or_null("ChallengeContainer")
	if chal_container:
		chal_container.hide()
	ChallengeManager.cleanup_challenge()
	_on_home_pressed()

func _show_rank_up(old_rank: Dictionary, new_rank: Dictionary) -> void:
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	bg.modulate.a = 0
	$UILayer.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "RANK UP!"
	title.label_settings = UITheme.ls_title_font(42, UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate.a = 0
	title.position.y = -50
	vbox.add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var old_emblem = UITheme.make_rank_emblem(old_rank, 80)
	old_emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	old_emblem.modulate.a = 0
	hbox.add_child(old_emblem)
	
	var arr = Label.new()
	arr.text = "▶"
	arr.label_settings = UITheme.ls_title_font(32, UITheme.WHITE)
	arr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arr.modulate.a = 0
	hbox.add_child(arr)
	
	var new_emblem_container = Control.new()
	new_emblem_container.custom_minimum_size = Vector2(120, 120)
	new_emblem_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(new_emblem_container)
	
	var new_emblem = UITheme.make_rank_emblem(new_rank, 120)
	new_emblem.size = Vector2(120, 120)
	new_emblem.position = Vector2(0, 0)
	new_emblem.pivot_offset = Vector2(60, 60)
	new_emblem.scale = Vector2.ZERO
	new_emblem_container.add_child(new_emblem)
	
	var new_rank_lbl = Label.new()
	new_rank_lbl.text = "NEW RANK:\n" + new_rank.name
	new_rank_lbl.label_settings = UITheme.ls_title_font(28, new_rank.color)
	new_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_rank_lbl.modulate.a = 0
	vbox.add_child(new_rank_lbl)
	
	var rew_vbox = VBoxContainer.new()
	rew_vbox.modulate.a = 0
	vbox.add_child(rew_vbox)
	
	if new_rank.reward > 0:
		var rew = Label.new()
		rew.text = "REWARD: +%d COINS" % new_rank.reward
		rew.label_settings = UITheme.ls_title_font(24, UITheme.YELLOW)
		rew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rew_vbox.add_child(rew)
		
		var rew_btn = UITheme.make_button("CLAIM", UITheme.GOLD)
		rew_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			CurrencyManager.add_coins(new_rank.reward)
			_cleanup_challenge_and_go_home(bg)
		)
		rew_vbox.add_child(rew_btn)
	else:
		var ok_btn = UITheme.make_button("CONTINUE", UITheme.CYAN)
		ok_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			_cleanup_challenge_and_go_home(bg)
		)
		rew_vbox.add_child(ok_btn)
		
	# ANIMATION SEQUENCE
	var tw = create_tween().bind_node(bg)
	
	# Fade in BG
	tw.tween_property(bg, "modulate:a", 1.0, 0.3)
	
	# Drop title
	tw.tween_property(title, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(title, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Fade old rank
	tw.tween_interval(0.2)
	tw.tween_property(old_emblem, "modulate:a", 1.0, 0.3)
	
	# Arrow appears
	tw.tween_interval(0.2)
	tw.tween_property(arr, "modulate:a", 1.0, 0.2)
	
	# Pop new rank!
	tw.tween_interval(0.2)
	tw.tween_callback(func():
		AudioManager.play(AudioManager.SND_EQUIP)
		
		# Confetti effect around new emblem
		for i in range(12):
			var conf = Label.new()
			conf.text = "✦"
			conf.label_settings = UITheme.ls_glow_title(32, new_rank.color, Color.WHITE)
			conf.position = Vector2(60, 60)
			new_emblem_container.add_child(conf)
			
			var angle = i * (PI * 2 / 12)
			var dist = randf_range(80, 140)
			var target_pos = Vector2(60, 60) + Vector2(cos(angle), sin(angle)) * dist
			
			var c_tw = bg.create_tween()
			c_tw.tween_property(conf, "position", target_pos, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			c_tw.parallel().tween_property(conf, "modulate:a", 0.0, 0.6).set_delay(0.2)
			c_tw.tween_callback(conf.queue_free)
	)
	tw.tween_property(new_emblem, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Fade new rank text
	tw.tween_interval(0.2)
	tw.tween_property(new_rank_lbl, "modulate:a", 1.0, 0.3)
	
	# Show rewards and buttons
	tw.tween_interval(0.3)
	tw.tween_property(rew_vbox, "modulate:a", 1.0, 0.3)
