extends Node2D

@export var lookahead_platforms: int = 10
@export var despawn_distance: float = 900.0

var screen_width: float = 540.0
const PLATFORM_SCENE = preload("res://scenes/platform/platform.tscn")
const MAX_ATTEMPTS: int = 8
const SCREEN_MARGIN: float = 30.0

const PLAYER_BOUNCE_FORCE: float = 760.0
const PLAYER_HORIZ_SPEED: float  = 380.0
const GRAVITY: float             = 1400.0

var _platforms: Array[Node] = []
var _last_platform_pos: Vector2 = Vector2.ZERO
var _last_platform_width: float = 220.0
var _platform_count: int = 0

var _taught_moving: bool = false
var _taught_spike: bool = false
var _taught_fragile: bool = false
var _taught_vanishing: bool = false
var _taught_risk: bool = false
var _taught_wind: bool = false
var _taught_laser: bool = false
var _taught_closing: bool = false

# Pattern System
var _difficult_pattern: Array = []
var _consecutive_hard: int = 0

var _chaos_history: Array = []

func initialize(start_pos: Vector2, sw: float) -> void:
	screen_width = sw
	_last_platform_pos = start_pos
	_last_platform_width = 220.0
	_platform_count = 0
	_difficult_pattern.clear()
	_consecutive_hard = 0
	_generate_initial_platforms(start_pos)

func clear_all() -> void:
	for p in _platforms:
		if is_instance_valid(p):
			p.queue_free()
	_platforms.clear()
	
	# Clear all other children (hazards like lasers, wind, closing traps)
	for child in get_children():
		child.queue_free()
	_platform_count = 0
	_last_platform_width = 220.0
	_difficult_pattern.clear()
	_consecutive_hard = 0

func _generate_initial_platforms(start_pos: Vector2) -> void:
	var first_pos = start_pos + Vector2(0, 80)
	_spawn_platform(first_pos, 260.0)
	for _i in range(lookahead_platforms + 2):
		_spawn_next_platform(true)

func update_generation(player_y: float, camera_y: float) -> void:
	while _last_platform_pos.y > player_y - 700:
		_spawn_next_platform(false)
	var cutoff_y: float = camera_y + despawn_distance
	var to_remove: Array[Node] = []
	for p in _platforms:
		if is_instance_valid(p) and p.global_position.y > cutoff_y:
			to_remove.append(p)
	for p in to_remove:
		_platforms.erase(p)
		p.queue_free()

func _spawn_next_platform(force_easy: bool) -> void:
	_platform_count += 1
	var chain: int = 0
	var score: int = 0
	if not force_easy and Engine.has_singleton("GameState"):
		chain = GameState.current_chain
		score = GameState.current_score

	var params: Dictionary = DifficultyManager.get_params(score, chain)
	
	var width: float = randf_range(params.get("w_min", 150.0), params.get("w_max", 200.0))
	if force_easy:
		width = randf_range(220.0, 260.0)
	
	var vert_min: float = params.get("v_min", 120.0) if not force_easy else 100.0
	var vert_max: float = params.get("v_max", 150.0) if not force_easy else 120.0
	var vert_dist: float = randf_range(vert_min, vert_max)
	var new_y: float = _last_platform_pos.y - vert_dist

	# RECOVERY PLATFORM LOGIC
	if not force_easy and _consecutive_hard >= randi_range(3, 4):
		_consecutive_hard = 0
		var r_width = randf_range(200.0, 230.0)
		var pos = _find_valid_position(new_y, r_width, vert_dist, params.get("h_off", 150.0) * 0.5, 0.0, 0.0)
		_spawn_platform(pos, r_width, 0, 0.0, 0.0, 0)
		return

	var p_type: int = 0
	var p_range: float = 0.0
	var p_speed: float = 0.0
	var p_spike: int = 3
	var is_risk_choice: bool = false
	var force_isolated_hazard: bool = false
	var dir_bias: float = 0.0
	
	if not force_easy:
		_consecutive_hard += 1
		var r = randf()
		
		# Fill pattern if empty
		if score >= 1000 and _difficult_pattern.is_empty():
			if r < 0.25: _difficult_pattern = [1, -1, 1, -1] # ZIGZAG
			elif r < 0.5: _difficult_pattern = [1, 2, 0, -2] # FAR SWITCH (2 means double bias)
			elif r < 0.75: _difficult_pattern = ["M", 0, "M", "M"] # MOVING CHAIN
			else: _difficult_pattern = ["P", "P", 0] # PRECISION (smaller)
			
		if not _difficult_pattern.is_empty():
			var step = _difficult_pattern.pop_front()
			if typeof(step) == TYPE_INT or typeof(step) == TYPE_FLOAT:
				dir_bias = float(step)
			elif step == "M":
				p_type = 1
				p_range = randf_range(100.0, 150.0)
				p_speed = randf_range(2.0, 3.5)
			elif step == "P":
				width *= 0.8
		
		# Apply challenge-specific rules overriding basic score bands
		if ChallengeManager.is_active():
			var chal = ChallengeManager.get_active_challenge()
			if not chal.is_empty():
				if "more_moving" in chal.rules and r < 0.6:
					p_type = 1; p_range = randf_range(100.0, 160.0); p_speed = randf_range(2.0, 3.5)
				if "faster_moving" in chal.rules and r < 0.6:
					p_type = 1; p_range = randf_range(120.0, 180.0); p_speed = randf_range(3.0, 5.0)
				if "wind" in chal.rules and r < 0.4:
					_spawn_wind(new_y + vert_dist*0.5, screen_width, vert_dist, score)
				if "vanishing" in chal.rules and r < 0.3: p_type = 4
				if "fake_hard" in chal.rules:
					width *= 1.35
					vert_dist *= 0.8
					if r < 0.3:
						p_type = 1
						p_range = randf_range(60.0, 100.0)
						p_speed = randf_range(1.0, 1.8)
					elif r < 0.5:
						p_type = 2
					elif r < 0.6:
						pass # Laser removed
				if "spikes" in chal.rules and r < 0.3: p_type = 3; p_spike = randi() % 3
				if "rare_spikes" in chal.rules and r < 0.1: p_type = 3; p_spike = randi() % 3
				if "faster_patterns" in chal.rules and _difficult_pattern.is_empty() and r < 0.5:
					_difficult_pattern = [1, -1, 1, -1]

				if "closing" in chal.rules and r < 0.2:
					_spawn_closing_trap(new_y + vert_dist*0.5, screen_width)
				if "risk_routes" in chal.rules and r < 0.3:
					is_risk_choice = true
				if "advanced_combinations" in chal.rules:
					_apply_chaos_hazards(new_y)
					p_type = randi_range(1, 5)
		
		# Apply normal score bands hazard logic if no challenge override sets a type
		elif score >= 20000:
			# CHAOS
			_apply_chaos_hazards(new_y)
			p_type = randi_range(1, 5)
			if p_type == 1:
				p_range = randf_range(80.0, 160.0)
				p_speed = randf_range(2.5, 4.5)
			elif p_type == 3: p_spike = randi() % 3
			elif p_type == 5: is_risk_choice = true
		elif score >= 10000:
			# MASTER
			_apply_expert_hazards(new_y, score, vert_dist)
			p_type = randi_range(1, 5)
			if p_type == 1:
				p_range = randf_range(100.0, 180.0)
				p_speed = randf_range(2.0, 4.0)
			elif p_type == 3: p_spike = randi() % 3
			elif p_type == 5: is_risk_choice = true
		elif score >= 5000:
			# EXPERT
			_apply_expert_hazards(new_y, score, vert_dist)
			p_type = randi_range(0, 5)
			if p_type == 1:
				p_range = randf_range(80.0, 160.0)
				p_speed = randf_range(2.0, 3.5)
			elif p_type == 3: p_spike = randi() % 3
			elif p_type == 5: is_risk_choice = true
		elif score >= 2500:
			# VERY HARD
			if r < 0.2: p_type = 1; p_range = randf_range(100.0, 180.0); p_speed = randf_range(2.5, 4.0)
			elif r < 0.4: p_type = 2
			elif r < 0.6: p_type = 3; p_spike = randi() % 3
			elif r < 0.7: p_type = 4
		elif score >= 1500:
			# HARD
			if not _taught_spike:
				p_type = 3; p_spike = 0; _taught_spike = true; force_isolated_hazard = true
			elif not _taught_vanishing and r < 0.3:
				p_type = 4; _taught_vanishing = true; force_isolated_hazard = true
			elif r < 0.25: p_type = 3; p_spike = randi() % 3
			elif r < 0.45: p_type = 2
			elif r < 0.65: p_type = 1; p_range = randf_range(100.0, 150.0); p_speed = randf_range(2.0, 3.5)
		elif score >= 1000:
			# CHALLENGE
			if not _taught_fragile:
				p_type = 2; _taught_fragile = true; force_isolated_hazard = true
			elif r < 0.25: p_type = 2
			elif r < 0.60: p_type = 1; p_range = randf_range(90.0, 140.0); p_speed = randf_range(2.0, 3.5)
		elif score >= 500:
			# PREPARATION
			if not _taught_moving:
				p_type = 1; p_range = 100.0; p_speed = 2.0; _taught_moving = true; force_isolated_hazard = true
			elif r < 0.40: p_type = 1; p_range = randf_range(80.0, 130.0); p_speed = randf_range(1.5, 3.0)
		else:
			# LEARNING
			if r < 0.10: p_type = 1; p_range = 60.0; p_speed = 1.0

	var max_horiz: float = params.get("h_off", 150.0) if not force_easy else 100.0
	
	if is_risk_choice:
		_spawn_risk_choice(new_y, width, vert_dist, max_horiz)
	else:
		var safe_width = width
		if p_type == 3: safe_width = width * 0.6
			
		var pos = _find_valid_position(new_y, safe_width, vert_dist, max_horiz, p_range, dir_bias)
		_spawn_platform(pos, width, p_type, p_range, p_speed, p_spike)
	
func _apply_expert_hazards(y_pos: float, score: int, vert_dist: float) -> void:
	if vert_dist > 160.0:
		var hazard_y = y_pos + (vert_dist * 0.5)
		var h_rand = randf()
		if not _taught_closing: _spawn_closing_trap(hazard_y, screen_width); _taught_closing = true
		elif not _taught_wind and h_rand < 0.75: _spawn_wind(hazard_y, screen_width, vert_dist * 0.8, score); _taught_wind = true
		else:
			if h_rand < 0.25: _spawn_closing_trap(hazard_y, screen_width)
			elif h_rand < 0.50: _spawn_wind(hazard_y, screen_width, vert_dist * 0.8, score)

func _apply_chaos_hazards(y_pos: float) -> void:
	var r = randf()
	if r < 0.33: _spawn_wind(y_pos - 100.0, screen_width, 120.0, 20000)
	elif r < 0.66: _spawn_closing_trap(y_pos - 80.0, screen_width)

func _spawn_laser(y_pos: float, vp_w: float, score: int) -> void:
	var script = load("res://scripts/hazards/laser_gate.gd")
	if not script: return
	var laser = Node2D.new()
	laser.set_script(script)
	var active = clamp(2.0 - (score / 20000.0), 0.8, 2.0)
	var off = clamp(2.5 - (score / 20000.0), 1.0, 2.5)
	laser.setup(vp_w, 0.8, active, off)
	laser.global_position = Vector2(vp_w/2, y_pos)
	add_child(laser)

func _spawn_closing_trap(y_pos: float, vp_w: float) -> void:
	var script = load("res://scripts/hazards/closing_trap.gd")
	if not script: return
	var trap = Node2D.new()
	trap.set_script(script)
	trap.setup(vp_w, 55.0) 
	trap.global_position = Vector2(vp_w/2, y_pos)
	add_child(trap)

func _spawn_wind(y_pos: float, vp_w: float, height: float, score: int) -> void:
	var script = load("res://scripts/hazards/wind_zone.gd")
	if not script: return
	var wind = Node2D.new()
	wind.set_script(script)
	var strength = clamp(50.0 + (score / 100.0), 50.0, 250.0)
	if randf() > 0.5: strength = -strength
	wind.setup(vp_w, height, strength)
	wind.global_position = Vector2(vp_w/2, y_pos)
	add_child(wind)

func _spawn_risk_choice(new_y: float, width: float, vert_dist: float, max_horiz: float) -> void:
	var safe_pos = _find_valid_position(new_y, width, vert_dist, max_horiz)
	_spawn_platform(safe_pos, width, 0)
	
	var risk_width = width * 0.6
	var actual_last = _last_platform_pos
	_last_platform_pos = actual_last
	var risk_pos = _find_valid_position(new_y, risk_width, vert_dist, max_horiz * 1.5)
	
	var risk_type = 1
	var r = randf()
	if r > 0.6: risk_type = 2
	
	_spawn_platform(risk_pos, risk_width, 5)
	_last_platform_pos = safe_pos

func _find_valid_position(new_y: float, width: float, vert_dist: float, max_horiz: float, p_range: float = 0.0, dir_bias: float = 0.0) -> Vector2:
	var half_w: float = width * 0.5
	var x_min: float = half_w + SCREEN_MARGIN
	var x_max: float = screen_width - half_w - SCREEN_MARGIN

	for attempt in range(MAX_ATTEMPTS):
		var horiz_offset: float
		var min_offset: float = max(80.0, max_horiz * 0.4)
		if attempt == 0 and dir_bias != 0.0:
			var bias_sign = sign(dir_bias)
			var mult = abs(dir_bias)
			horiz_offset = bias_sign * randf_range(min_offset * mult, max_horiz * mult)
		else:
			var direction = 1.0 if randf() > 0.5 else -1.0
			var range_mult = float(attempt + 1) / float(MAX_ATTEMPTS)
			var cur_max = max(min_offset + 10.0, max_horiz * range_mult)
			horiz_offset = direction * randf_range(min_offset, cur_max)

		var new_x: float = clamp(_last_platform_pos.x + horiz_offset, x_min, x_max)
		var candidate = Vector2(new_x, new_y)

		if _is_reachable(candidate, width, vert_dist, p_range):
			return candidate

	var safe_x: float = clamp(_last_platform_pos.x, x_min, x_max)
	return Vector2(safe_x, new_y)

func _is_reachable(new_pos: Vector2, _width: float, vert_dist: float, p_range: float = 0.0) -> bool:
	var v0: float = PLAYER_BOUNCE_FORCE
	var discriminant: float = v0 * v0 - 2.0 * GRAVITY * vert_dist

	if discriminant < 0:
		return false

	var t_up: float = (v0 - sqrt(discriminant)) / GRAVITY
	var t_total: float = (v0 + sqrt(discriminant)) / GRAVITY

	var max_reach: float = PLAYER_HORIZ_SPEED * t_total
	max_reach -= 20.0 

	var horiz_dist: float = abs(new_pos.x - _last_platform_pos.x)
	if p_range > 0.0:
		var dist_to_closest = max(0.0, horiz_dist - p_range)
		return dist_to_closest <= max_reach
	return horiz_dist <= max_reach

func _spawn_platform(pos: Vector2, width: float, p_type: int = 0, p_range: float = 0.0, p_speed: float = 0.0, p_spike: int = 3) -> void:
	var p = PLATFORM_SCENE.instantiate()
	add_child(p)
	p.global_position = pos
	p.setup(width, 22.0, p_type, p_range, p_speed)
	
	if p_type == 3 and p.has_method("setup_spike"):
		p.setup_spike(p_spike)
	if ChallengeManager.is_active():
		var chal = ChallengeManager.get_active_challenge()
		if "flicker" in chal.rules and p.has_method("setup_flicker"):
			if randf() < 0.6:
				p.setup_flicker(randf_range(2.0, 5.0))
		if "shrink" in chal.rules and p.has_method("setup_shrink"):
			if randf() < 0.5:
				p.setup_shrink()
		
	_platforms.append(p)
	_last_platform_pos = pos
	_last_platform_width = width

func spawn_safe_platform(y_pos: float, width: float) -> void:
	var safe_pos = Vector2(screen_width * 0.5, y_pos)
	_spawn_platform(safe_pos, width)
