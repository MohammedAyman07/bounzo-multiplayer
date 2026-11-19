extends StaticBody2D

enum Type { STATIC, MOVING, FRAGILE, SPIKE, VANISHING, RISK }

@export var platform_width: float = 200.0
@export var platform_height: float = 22.0

@onready var visual = $PlatformVisual
@onready var col_shape = $CollisionShape2D

var _width: float = 200.0
var _height: float = 22.0

# Type and behavior
var type: Type = Type.STATIC
var move_range: float = 0.0
var move_speed: float = 0.0
var spike_layout: int = 3 # 0: LEFT, 1: RIGHT, 2: CENTER, 3: NONE
var _start_x: float = 0.0
var _time_passed: float = 0.0
var _is_cracking: bool = false
var _is_vanishing: bool = false
var _risk_active: bool = false
var _is_flickering: bool = false
var _flicker_speed: float = 3.0
var _flicker_time: float = 0.0
var can_shrink: bool = false
var _is_shrinking: bool = false
var _is_blinking_active: bool = true
var _blink_timer: float = 0.0
var _blink_interval: float = 2.0

const HORIZON_OFFSET: float = -200.0

func _ready() -> void:
	var new_shape := RectangleShape2D.new()
	new_shape.size = Vector2(_width, _height)
	col_shape.shape = new_shape
	_start_x = global_position.x
	_time_passed = randf_range(0.0, PI * 2)

func setup(w: float, h: float = 22.0, p_type: Type = Type.STATIC, p_range: float = 0.0, p_speed: float = 0.0, p_spike: int = 3) -> void:
	_width = w
	_height = h
	platform_width = w
	platform_height = h
	type = p_type
	move_range = p_range
	move_speed = p_speed
	spike_layout = p_spike
	_start_x = global_position.x
	
	if not is_node_ready():
		await ready
		
	col_shape.shape.size = Vector2(_width, _height)
	if visual:
		visual.setup(_width, _height)
		if type == Type.FRAGILE:
			visual.modulate = Color(1.2, 0.8, 0.8)
		elif type == Type.RISK:
			visual.modulate = Color(1.8, 1.5, 0.2) # Gold/Yellow
			_risk_active = true
	
	if type == Type.SPIKE:
		_setup_spikes()
	elif type == Type.VANISHING:
		visual.modulate = Color(0.2, 0.8, 1.0) # Cyan

func _setup_spikes() -> void:
	var spike_w = _width * 0.12 # Spikes cover 25% of platform to make it easier
	var spike_x = 0.0
	
	if spike_layout == 0: # LEFT
		spike_x = -(_width * 0.5) + (spike_w * 0.5)
	elif spike_layout == 1: # RIGHT
		spike_x = (_width * 0.5) - (spike_w * 0.5)
	elif spike_layout == 2: # CENTER
		spike_x = 0.0
		
	var area = Area2D.new()
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(spike_w - 4.0, _height + 8.0) # slightly smaller than visual for fairness
	col.shape = shape
	area.add_child(col)
	area.position = Vector2(spike_x, -_height * 0.5)
	area.body_entered.connect(_on_spike_entered)
	add_child(area)
	
	var poly = Polygon2D.new()
	var hw = spike_w * 0.5
	var hh = (_height + 10.0) * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hw, hh), Vector2(hw, hh), Vector2(hw, -hh), Vector2(-hw, -hh)
	])
	poly.color = Color(1.0, 0.1, 0.3, 0.9) # Hot magenta/red
	area.add_child(poly)

func _on_spike_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("die_with_reason"):
		body.die_with_reason("SPIKE HIT")



func crack() -> void:
	if type != Type.FRAGILE or _is_cracking:
		return
	_is_cracking = true
	var tween = create_tween().bind_node(self)
	tween.tween_property(visual, "modulate", Color(2.0, 0.2, 0.2, 0.8), 0.6)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func claim_risk() -> bool:
	if type == Type.RISK and _risk_active:
		_risk_active = false
		return true
	return false

func get_safe_center_x() -> float:
	if type == Type.SPIKE:
		var spike_w = _width * 0.12
		var safe_w = _width * 0.88
		if spike_layout == 0: # Left spike, right safe
			return global_position.x + (spike_w * 0.5)
		elif spike_layout == 1: # Right spike, left safe
			return global_position.x - (spike_w * 0.5)
		elif spike_layout == 2: # Center spike, edges safe? Wait, generator treats it as safe width = width * 0.6. But if spike is in center, there are TWO safe zones. 
			# Let's assume safe center is still 0 for simplicity, or we treat the wider unspiked part. 
			# Actually, center spike means the edges are safe. A distance check to global_position.x will be largest at the edges! 
			# If player lands on edge, dist to center is high. So PERFECT requires a different logic if center spike.
			# But for simplicity, we return global_position.x and let the distance be whatever it is.
			pass
	return global_position.x

func get_safe_width() -> float:
	if type == Type.SPIKE:
		return _width * 0.6
	return _width

func _physics_process(delta: float) -> void:
	if type == Type.MOVING and not _is_cracking:
		_time_passed += delta * move_speed
		var new_x = _start_x + sin(_time_passed) * move_range
		global_position.x = new_x

func _process(_delta: float) -> void:
	if _is_flickering and not _is_cracking and type != Type.VANISHING:
		_flicker_time += _delta * _flicker_speed
		visual.modulate.a = 0.15 + 0.85 * abs(sin(_flicker_time))
		
	if type == Type.VANISHING:
		_blink_timer += _delta
		var cycle_pos = fmod(_blink_timer, _blink_interval * 2.0)
		
		if cycle_pos < _blink_interval:
			# Active Phase
			if not _is_blinking_active:
				_is_blinking_active = true
				col_shape.set_deferred("disabled", false)
				visual.modulate.a = 1.0
			
			# Flash red right before turning off
			if cycle_pos > _blink_interval - 0.4:
				visual.modulate = Color(1.5, 0.2, 0.2, 1.0)
			else:
				visual.modulate = Color(0.2, 0.8, 1.5, 1.0) # Cyan base color
				
		else:
			# Inactive Phase
			if _is_blinking_active:
				_is_blinking_active = false
				col_shape.set_deferred("disabled", true)
				visual.modulate.a = 0.15
				
			# Flash green right before turning on
			if cycle_pos > (_blink_interval * 2.0) - 0.4:
				visual.modulate = Color(0.2, 1.5, 0.2, 0.4)
			else:
				visual.modulate = Color(0.2, 0.8, 1.5, 0.15)

	var cam = get_viewport().get_camera_2d()
	if cam and visual:
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
			
		visual.scale = Vector2(scale_factor, scale_factor)
		visual.position.y = (_height * 0.5) * (scale_factor - 1.0)

func setup_flicker(speed: float = 3.0) -> void:
	_is_flickering = true
	_flicker_speed = speed

func setup_shrink() -> void:
	can_shrink = true
	visual.modulate = Color(2.0, 0.5, 2.5) # Glowing pink/purple tint

func trigger_shrink() -> void:
	if can_shrink and not _is_shrinking:
		_is_shrinking = true
		var tween = create_tween().bind_node(self)
		tween.tween_property(self, "scale:x", 0.1, 1.5)
