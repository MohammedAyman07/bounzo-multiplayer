extends Node2D

var width: float = 600.0
var thickness: float = 30.0
var min_gap: float = 120.0 # Will be updated based on player width

var left_visual: ColorRect
var right_visual: ColorRect
var left_area: Area2D
var right_area: Area2D
var left_col: CollisionShape2D
var right_col: CollisionShape2D

var _timer: float = 0.0
var _phase: int = 0 # 0=open, 1=warning, 2=closing, 3=hold, 4=opening
var _current_gap: float = width

# Timing config
var open_time: float = 2.0
var warning_time: float = 0.8
var close_time: float = 0.5
var hold_time: float = 1.0
var open_speed: float = 0.8

const HORIZON_OFFSET: float = -200.0

func _ready() -> void:
	# Left Side
	left_visual = ColorRect.new()
	left_visual.color = Color(1, 0, 0, 0.8)
	add_child(left_visual)
	left_area = Area2D.new()
	left_col = CollisionShape2D.new()
	left_area.add_child(left_col)
	add_child(left_area)
	left_area.body_entered.connect(_on_body_entered)
	
	# Right Side
	right_visual = ColorRect.new()
	right_visual.color = Color(1, 0, 0, 0.8)
	add_child(right_visual)
	right_area = Area2D.new()
	right_col = CollisionShape2D.new()
	right_area.add_child(right_col)
	add_child(right_area)
	right_area.body_entered.connect(_on_body_entered)
	
	_update_visuals()

func setup(w: float, player_w: float) -> void:
	width = w
	min_gap = player_w + 50.0 # Safety margin
	_current_gap = width
	_update_visuals()

func _update_visuals() -> void:
	if not left_visual: return
	
	var side_w = (width - _current_gap) * 0.5
	
	# Left
	left_visual.size = Vector2(side_w, thickness)
	left_visual.position = Vector2(-width/2, -thickness/2)
	left_col.shape = RectangleShape2D.new()
	left_col.shape.size = Vector2(side_w, thickness)
	left_area.position = Vector2(-width/2 + side_w/2, 0)
	
	# Right
	right_visual.size = Vector2(side_w, thickness)
	right_visual.position = Vector2(width/2 - side_w, -thickness/2)
	right_col.shape = RectangleShape2D.new()
	right_col.shape.size = Vector2(side_w, thickness)
	right_area.position = Vector2(width/2 - side_w/2, 0)

func _physics_process(delta: float) -> void:
	_timer += delta
	
	if _phase == 0: # OPEN
		if _timer >= open_time:
			_phase = 1
			_timer = 0.0
			left_visual.color = Color(1, 0.5, 0, 1.0)
			right_visual.color = Color(1, 0.5, 0, 1.0)
	elif _phase == 1: # WARNING
		# Pulse
		var pulse = abs(sin(_timer * 15.0))
		left_visual.color = Color(1, pulse, 0, 1.0)
		right_visual.color = Color(1, pulse, 0, 1.0)
		if _timer >= warning_time:
			_phase = 2
			_timer = 0.0
			left_visual.color = Color(1, 0, 0, 1.0)
			right_visual.color = Color(1, 0, 0, 1.0)
	elif _phase == 2: # CLOSING
		var t = _timer / close_time
		if t >= 1.0:
			t = 1.0
			_phase = 3
			_timer = 0.0
		# Ease out bounce or ease out quad
		t = 1.0 - (1.0 - t) * (1.0 - t)
		_current_gap = lerp(width, min_gap, t)
		_update_visuals()
	elif _phase == 3: # HOLD
		if _timer >= hold_time:
			_phase = 4
			_timer = 0.0
	elif _phase == 4: # OPENING
		var t = _timer / open_speed
		if t >= 1.0:
			t = 1.0
			_phase = 0
			_timer = 0.0
		_current_gap = lerp(min_gap, width, t)
		_update_visuals()

func _process(_delta: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if cam:
		var cam_y = cam.global_position.y
		var horizon_y = cam_y + HORIZON_OFFSET
		var dist = global_position.y - horizon_y
		
		var scale_factor = 1.0
		if dist > 0:
			var t = clamp(dist / 800.0, 0.0, 1.0)
			t = pow(t, 1.5)
			scale_factor = lerp(0.2, 1.8, t)
		else:
			scale_factor = 0.2
			
		scale = Vector2(scale_factor, scale_factor)
		
		if global_position.y > cam.get_bottom_world_y() + 500:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if body.has_method("die_with_reason"):
			body.die_with_reason("CLOSED IN")
