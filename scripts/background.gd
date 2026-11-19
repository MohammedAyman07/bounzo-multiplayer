extends Node2D

var _camera: Camera2D = null
var _screen_w: float = 540.0
var _screen_h: float = 960.0

# Colors for Cyberpunk/Neon City Theme
# Colors for Cyberpunk/Neon City Theme
var bg_sky       = Color(0.02, 0.01, 0.06, 1.0)
var bg_horizon   = Color(0.08, 0.03, 0.15, 1.0)
var grid_color   = Color(0.85, 0.20, 1.00, 0.12)
var city_bg      = Color(0.02, 0.0, 0.05, 1.0)
var city_mid     = Color(0.04, 0.01, 0.10, 1.0)
var city_fg      = Color(0.08, 0.01, 0.20, 1.0)
var city_hilite  = Color(0.40, 0.05, 0.80, 0.6)

var _target_sky       = bg_sky
var _target_horizon   = bg_horizon
var _target_grid      = grid_color
var _target_city_bg   = city_bg
var _target_city_mid  = city_mid
var _target_city_fg   = city_fg
var _target_city_hilite = city_hilite  

# Horizon offset relative to the camera center.
const HORIZON_OFFSET: float = -200.0


func setup(cam: Camera2D, sw: float, sh: float) -> void:
	_camera = cam
	_screen_w = sw
	_screen_h = sh
	
	var wpm = get_node_or_null("/root/WorldPhaseManager")
	if wpm:
		wpm.phase_changed.connect(_on_phase_changed)
		var config = wpm.current_phase_config
		if not config.is_empty():
			_set_instant_colors(config)

func _set_instant_colors(config: Dictionary) -> void:
	bg_sky = config["sky"]
	bg_horizon = config["horizon"]
	grid_color = config["grid"]
	city_bg = config["city_bg"]
	city_mid = config["city_mid"]
	city_fg = config["city_fg"]
	city_hilite = config["city_hilite"]
	
	_target_sky = bg_sky
	_target_horizon = bg_horizon
	_target_grid = grid_color
	_target_city_bg = city_bg
	_target_city_mid = city_mid
	_target_city_fg = city_fg
	_target_city_hilite = city_hilite

func _on_phase_changed(_id: int, _name: String) -> void:
	var wpm = get_node_or_null("/root/WorldPhaseManager")
	if not wpm: return
	var config = wpm.current_phase_config
	_target_sky = config["sky"]
	_target_horizon = config["horizon"]
	_target_grid = config["grid"]
	_target_city_bg = config["city_bg"]
	_target_city_mid = config["city_mid"]
	_target_city_fg = config["city_fg"]
	_target_city_hilite = config["city_hilite"]

func _process(delta: float) -> void:
	var t = delta * 1.5
	bg_sky = bg_sky.lerp(_target_sky, t)
	bg_horizon = bg_horizon.lerp(_target_horizon, t)
	grid_color = grid_color.lerp(_target_grid, t)
	city_bg = city_bg.lerp(_target_city_bg, t)
	city_mid = city_mid.lerp(_target_city_mid, t)
	city_fg = city_fg.lerp(_target_city_fg, t)
	city_hilite = city_hilite.lerp(_target_city_hilite, t)
	queue_redraw()


func _draw() -> void:
	if not _camera:
		return

	var cam_y: float = _camera.global_position.y
	var top_y: float = cam_y - _screen_h * 0.5 - 200.0
	var bot_y: float = cam_y + _screen_h * 0.5 + 200.0
	var horizon_y: float = cam_y + HORIZON_OFFSET

	# 1. Sky Gradient (Top to Horizon)
	var sky_poly = PackedVector2Array([
		Vector2(-_screen_w, top_y),
		Vector2(_screen_w * 2.0, top_y),
		Vector2(_screen_w * 2.0, horizon_y),
		Vector2(-_screen_w, horizon_y)
	])
	var sky_colors = PackedColorArray([bg_sky, bg_sky, bg_horizon, bg_horizon])
	draw_polygon(sky_poly, sky_colors)
	
	# 1.5 Stars / Dust
	seed(42)
	for i in range(40):
		var sx = randf_range(-_screen_w, _screen_w * 2.0)
		var sy = randf_range(top_y, horizon_y)
		var a = randf_range(0.2, 0.8)
		draw_circle(Vector2(sx, sy), randf_range(0.5, 1.5), Color(1, 1, 1, a))

	# 2. Ground/Grid Base (Horizon to Bottom)
	var ground_poly = PackedVector2Array([
		Vector2(-_screen_w, horizon_y),
		Vector2(_screen_w * 2.0, horizon_y),
		Vector2(_screen_w * 2.0, bot_y),
		Vector2(-_screen_w, bot_y)
	])
	var ground_colors = PackedColorArray([bg_horizon, bg_horizon, bg_sky, bg_sky])
	draw_polygon(ground_poly, ground_colors)

	# 3. Parallax City Silhouette in 3 Layers
	var parallax_bg = wrapf(cam_y * 0.1, 0.0, 1000.0)
	var parallax_mid = wrapf(cam_y * 0.2, 0.0, 1000.0)
	var parallax_fg = wrapf(cam_y * 0.35, 0.0, 1000.0)
	
	_draw_city_layer(horizon_y, -_screen_w * 0.5 - parallax_bg, _screen_w * 2.5, 111, city_bg, 100.0, 300.0, false)
	_draw_city_layer(horizon_y, -_screen_w * 0.5 - parallax_mid, _screen_w * 2.5, 222, city_mid, 60.0, 200.0, false)
	_draw_city_layer(horizon_y, -_screen_w * 0.5 - parallax_fg, _screen_w * 2.5, 333, city_fg, 30.0, 120.0, true)

	# 4. Horizon atmospheric glow
	draw_circle(Vector2(_screen_w * 0.5, horizon_y), 400.0, Color(0.6, 0.1, 0.8, 0.15))

	# 5. Perspective Neon Grid
	_draw_perspective_grid(cam_y, horizon_y, bot_y)


func _draw_city_layer(horizon_y: float, start_x: float, end_x: float, lseed: int, color: Color, min_h: float, max_h: float, draw_windows: bool) -> void:
	seed(lseed)
	var cx: float = start_x
	while cx < end_x:
		var width: float = randf_range(30.0, 90.0)
		var height: float = randf_range(min_h, max_h)
		var gap: float = randf_range(5.0, 15.0)
		
		# Draw solid building
		var bldg_rect = Rect2(cx, horizon_y - height, width, height)
		draw_rect(bldg_rect, color)
		
		# Neon edge highlights
		draw_line(Vector2(cx, horizon_y), Vector2(cx, horizon_y - height), city_hilite, 1.0)
		draw_line(Vector2(cx, horizon_y - height), Vector2(cx + width, horizon_y - height), city_hilite, 2.0)
		draw_line(Vector2(cx + width, horizon_y - height), Vector2(cx + width, horizon_y), city_hilite, 1.0)
		
		# Random windows for foreground
		if draw_windows and randf() > 0.4:
			var win_cols = [Color(0.0, 0.8, 1.0, 0.8), Color(0.8, 0.2, 1.0, 0.8)]
			for wy in range(int(horizon_y - height + 10), int(horizon_y - 10), 15):
				for wx in range(int(cx + 10), int(cx + width - 10), 12):
					if randf() > 0.6:
						draw_rect(Rect2(wx, wy, 4, 6), win_cols[randi() % 2])
						
		cx += width + gap


func _draw_perspective_grid(cam_y: float, horizon_y: float, bot_y: float) -> void:
	var vp_x: float = _screen_w * 0.5
	var num_v_lines: int = 15
	var spacing_x: float = 120.0
	
	# --- Vertical Lines (Converging to horizon X=center) ---
	var start_idx: int = -num_v_lines / 2
	for i in range(num_v_lines):
		var x_offset = (start_idx + i) * spacing_x
		
		# The bottom of the line spreads out, the top converges at horizon center
		var horizon_pt = Vector2(vp_x, horizon_y)
		
		# Scale X offset by distance from horizon to get the bottom point
		var dist_to_bot = bot_y - horizon_y
		var spread_factor = 4.0
		var bottom_pt = Vector2(vp_x + (x_offset * spread_factor), bot_y)
		
		draw_line(horizon_pt, bottom_pt, grid_color, 1.5)

	# --- Horizontal Lines (Moving forward) ---
	# To make it look like we are moving forward, we shift the lines based on cam_y
	var move_speed: float = 0.005
	var offset: float = wrapf(-cam_y * move_speed, 0.0, 1.0)
	
	var num_h_lines: int = 25
	for i in range(num_h_lines):
		# Z represents distance (0.0 is horizon, 1.0 is near camera, >1 is behind camera)
		# We use exponential spacing for perspective
		var z = (i + offset) * 0.1
		
		# Avoid drawing exactly at horizon (divide by zero or infinity)
		if z < 0.02:
			continue
			
		var y_pos = horizon_y + (100.0 / z)
		
		if y_pos > horizon_y and y_pos < bot_y:
			# Fade out near horizon
			var dist_from_horizon = y_pos - horizon_y
			var alpha_factor = clamp(dist_from_horizon / 120.0, 0.0, 1.0)
			
			var c = grid_color
			c.a *= alpha_factor
			
			draw_line(Vector2(-_screen_w, y_pos), Vector2(_screen_w * 2.0, y_pos), c, 1.5)
