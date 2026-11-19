class_name MultiplayerPlatformGenerator
extends Node2D

# ==============================================================================
# MULTIPLAYER PLATFORM GENERATOR
# Generates deterministic, synchronized platforms for all 4 players using course_seed.
# Features escalating obstacles: Moving, Fragile, Spikes, Vanishing, and Shrinking!
# ==============================================================================

const PLATFORM_SCENE = preload("res://scenes/platform/platform.tscn")
const TOTAL_RACE_PLATFORMS: int = 500
const SCREEN_MARGIN: float = 30.0

var screen_width: float = 540.0
var _platforms: Array[Node] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func initialize(seed_val: int, start_pos: Vector2, sw: float, difficulty: String = "NORMAL") -> void:
	clear_all()
	screen_width = sw
	_rng.seed = seed_val

	var diff_clean = difficulty.to_upper().strip_edges()
	var width_mult: float = 1.0
	var vert_mult: float = 1.0
	var speed_mult: float = 1.0
	var hazard_start: int = 8
	var spike_prob_mult: float = 1.0

	match diff_clean:
		"EASY":
			width_mult = 1.25
			vert_mult = 0.90
			speed_mult = 0.75
			hazard_start = 14
			spike_prob_mult = 0.5
		"HARD":
			width_mult = 0.85
			vert_mult = 1.08
			speed_mult = 1.35
			hazard_start = 5
			spike_prob_mult = 1.3
		"INSANE":
			width_mult = 0.70
			vert_mult = 1.15
			speed_mult = 1.70
			hazard_start = 3
			spike_prob_mult = 1.6
		_: # NORMAL
			width_mult = 1.0
			vert_mult = 1.0
			speed_mult = 1.0
			hazard_start = 8
			spike_prob_mult = 1.0

	# First starting platform directly beneath starting line
	var first_pos = start_pos + Vector2(0, 80)
	_spawn_platform(first_pos, 280.0 * width_mult, 0, 0.0, 0.0, 3, false)

	var last_pos: Vector2 = first_pos
	var last_width: float = 280.0 * width_mult

	for i in range(1, TOTAL_RACE_PLATFORMS):
		# Difficulty scales with height (platform index)
		var progress: float = clamp(float(i) / float(TOTAL_RACE_PLATFORMS), 0.0, 1.0)
		
		# Platform width gradually narrows as players climb
		var width_min: float = lerp(200.0, 120.0, progress) * width_mult
		var width_max: float = lerp(260.0, 160.0, progress) * width_mult
		var width: float = _rng.randf_range(width_min, width_max)

		# Vertical jump distance
		var vert_min: float = lerp(110.0, 140.0, progress) * vert_mult
		var vert_max: float = lerp(130.0, 165.0, progress) * vert_mult
		var vert_dist: float = _rng.randf_range(vert_min, vert_max)
		var new_y: float = last_pos.y - vert_dist

		# Horizontal offset
		var max_h_off: float = lerp(130.0, 195.0, progress)
		var h_dir: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var h_dist: float = _rng.randf_range(50.0, max_h_off)
		var target_x: float = clamp(last_pos.x + (h_dist * h_dir), SCREEN_MARGIN + (width * 0.5), screen_width - SCREEN_MARGIN - (width * 0.5))

		# Obstacle Types (platform.gd enum Type { STATIC=0, MOVING=1, FRAGILE=2, SPIKE=3, VANISHING=4, RISK=5 })
		var p_type: int = 0
		var move_speed: float = 0.0
		var move_range: float = 0.0
		var spike_layout: int = 3 # 3 = NONE, 0 = LEFT, 1 = RIGHT, 2 = CENTER
		var is_shrink: bool = false

		if i > hazard_start:
			var roll = _rng.randf()
			# Phase 1: Mostly static with moving platforms
			if i <= 25:
				if roll < (0.30 * speed_mult):
					p_type = 1 # MOVING
					move_range = _rng.randf_range(60.0, 100.0)
					move_speed = _rng.randf_range(1.5, 2.5) * speed_mult
			# Phase 2 (i: 26..60): Moving + Fragile (crumbles) + Shrink
			elif i <= 60:
				if roll < 0.28:
					p_type = 1 # MOVING
					move_range = _rng.randf_range(80.0, 130.0)
					move_speed = _rng.randf_range(2.0, 3.2)
				elif roll < 0.52:
					p_type = 2 # FRAGILE (breaks on jump!)
				elif roll < 0.68:
					is_shrink = true
			# Phase 3 (i: 61..140): Spikes introduced + Fragile + Moving
			elif i <= 140:
				if roll < 0.22:
					p_type = 3 # SPIKE HAZARD!
					spike_layout = _rng.randi() % 3
				elif roll < 0.44:
					p_type = 1 # MOVING
					move_range = _rng.randf_range(90.0, 150.0)
					move_speed = _rng.randf_range(2.2, 3.8)
				elif roll < 0.65:
					p_type = 2 # FRAGILE
				elif roll < 0.78:
					is_shrink = true
			# Phase 4 (i: 141..280): Vanishing (phases in/out) + Spikes + Moving
			elif i <= 280:
				if roll < 0.22:
					p_type = 4 # VANISHING!
				elif roll < 0.42:
					p_type = 3 # SPIKE HAZARD!
					spike_layout = _rng.randi() % 3
				elif roll < 0.62:
					p_type = 1 # MOVING
					move_range = _rng.randf_range(100.0, 160.0)
					move_speed = _rng.randf_range(2.5, 4.2)
				elif roll < 0.80:
					p_type = 2 # FRAGILE
			# Phase 5 (i: 281+): Ultimate Chaos Gauntlet
			else:
				if roll < 0.25:
					p_type = 4 # VANISHING
				elif roll < 0.50:
					p_type = 3 # SPIKE HAZARD!
					spike_layout = _rng.randi() % 3
				elif roll < 0.72:
					p_type = 1 # MOVING
					move_range = _rng.randf_range(100.0, 170.0)
					move_speed = _rng.randf_range(2.8, 4.5)
				elif roll < 0.88:
					p_type = 2 # FRAGILE
				else:
					is_shrink = true

		var pos = Vector2(target_x, new_y)
		_spawn_platform(pos, width, p_type, move_speed, move_range, spike_layout, is_shrink)
		last_pos = pos
		last_width = width

func _spawn_platform(pos: Vector2, width: float, p_type: int = 0, move_speed: float = 0.0, move_range: float = 0.0, spike_layout: int = 3, is_shrink: bool = false) -> Node:
	var p = PLATFORM_SCENE.instantiate()
	p.position = pos
	add_child(p)
	p.setup(width, 22.0, p_type, move_range, move_speed, spike_layout)
	if is_shrink and p.has_method("setup_shrink"):
		p.setup_shrink()
	_platforms.append(p)
	return p

func clear_all() -> void:
	for p in _platforms:
		if is_instance_valid(p):
			p.queue_free()
	_platforms.clear()
	for child in get_children():
		child.queue_free()

