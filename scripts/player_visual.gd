extends Node2D

var trail_points: Array[Vector2] = []
var trail_max: int = 25
var _player_global_pos: Vector2 = Vector2.ZERO
var _landing_burst_time: float = 0.0

# Colors (loaded from cosmetics)
var color_core: Color = Color(1.0, 1.0, 1.0, 1.0)
var color_inner: Color = Color(0.0, 0.9, 1.0, 1.0)
var color_outer: Color = Color(0.0, 0.5, 1.0, 0.6)
var color_glow: Color = Color(0.0, 0.3, 1.0, 0.15)

var trail_inner: Color = Color(0.0, 0.9, 1.0, 1.0)
var trail_outer: Color = Color(0.0, 0.4, 1.0, 1.0)
var trail_spark: Color = Color(0.5, 1.0, 1.0, 1.0)

func _ready() -> void:
	_load_cosmetics()
	var cd = get_node_or_null("/root/CosmeticData")
	if cd and cd.has_signal("cosmetics_changed"):
		cd.cosmetics_changed.connect(_load_cosmetics)


func _load_cosmetics() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	var cd = get_node_or_null("/root/CosmeticData")
	var selected_ball = "basic"
	var selected_trail = "basic"
	if sm and "data" in sm and sm.data is Dictionary:
		selected_ball = sm.data.get("selected_ball", "basic")
		selected_trail = sm.data.get("selected_trail", "basic")
	
	if cd and cd.has_method("get_ball"):
		var ball_data = cd.get_ball(selected_ball)
		color_core = ball_data.get("core", color_core)
		color_inner = ball_data.get("inner", color_inner)
		color_outer = ball_data.get("outer", color_outer)
		color_glow = ball_data.get("glow", color_glow)
		
		var trail_data = cd.get_trail(selected_trail)
		trail_inner = trail_data.get("inner", trail_inner)
		trail_outer = trail_data.get("outer", trail_outer)
		trail_spark = trail_data.get("spark", trail_spark)


var _shadow_dist: float = -1.0


func _process(delta: float) -> void:
	if _landing_burst_time > 0.0:
		_landing_burst_time -= delta
	queue_redraw()


func emit_landing_burst() -> void:
	_landing_burst_time = 0.4


func update_shadow(dist: float) -> void:
	_shadow_dist = dist


func update_trail(gpos: Vector2) -> void:
	_player_global_pos = gpos
	trail_points.push_front(gpos)
	if trail_points.size() > trail_max:
		trail_points.pop_back()


func clear_trail() -> void:
	trail_points.clear()


func _draw() -> void:
	# 1. Trail
	# Draw ribbon-like trail using thick overlapping circles
	for i in trail_points.size():
		var pt = trail_points[i] - global_position
		var factor = float(i) / float(trail_max)
		var alpha: float = (1.0 - factor) * 0.8
		var radius: float = lerp(18.0, 2.0, factor)
		
		# Inner bright cyan core
		var t_inner = trail_inner
		t_inner.a = alpha
		draw_circle(pt, radius, t_inner)
		# Outer blue glow
		var t_outer = trail_outer
		t_outer.a = alpha * 0.4
		draw_circle(pt, radius * 2.0, t_outer)
		
		# Add a few random sparks if moving
		if i % 3 == 0 and factor < 0.5:
			# Deterministic random based on position so they don't jitter wildly
			seed(int(pt.y * 100))
			var spark_offset = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
			var t_spark = trail_spark
			t_spark.a = alpha
			draw_circle(pt + spark_offset, randf_range(1.0, 3.0), t_spark)

	# 1.5. Shadow
	if _shadow_dist >= 0.0 and _shadow_dist < 600.0:
		var shadow_y = _shadow_dist
		var shadow_progress = _shadow_dist / 600.0
		var shadow_radius = lerp(24.0, 6.0, shadow_progress)
		var shadow_alpha = (1.0 - shadow_progress) * 0.5
		var pts = PackedVector2Array()
		for a in range(16):
			var angle = (a / 16.0) * TAU
			pts.append(Vector2(cos(angle)*shadow_radius*2.0, shadow_y + sin(angle)*shadow_radius))
		draw_colored_polygon(pts, Color(0, 0, 0, shadow_alpha))

	# 2. Main Ball Glow (1.5x Larger)
	draw_circle(Vector2.ZERO, 45.0, color_glow)
	draw_circle(Vector2.ZERO, 30.0, color_outer)

	# 3. Main Body
	draw_circle(Vector2.ZERO, 19.5, color_inner)

	# 4. Core Specular
	draw_circle(Vector2.ZERO, 9.0, color_core)
	draw_circle(Vector2(-4.5, -6.0), 4.5, Color(1.0, 1.0, 1.0, 0.9))
	
	# Circular energy effect (subtle ring)
	draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.5), 2.0)

	# 5. Landing burst ring
	if _landing_burst_time > 0.0:
		var progress = 1.0 - (_landing_burst_time / 0.4)
		var burst_r = lerp(19.5, 60.0, progress)
		var burst_a = (1.0 - progress) * 0.9
		draw_arc(Vector2.ZERO, burst_r, 0.0, TAU, 32, Color(0.0, 1.0, 1.0, burst_a), 4.0)
		draw_arc(Vector2.ZERO, burst_r * 1.3, 0.0, TAU, 32, Color(0.4, 0.6, 1.0, burst_a * 0.4), 2.0)
