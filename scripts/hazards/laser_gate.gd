extends Node2D

enum State { OFF, WARNING, ACTIVE }
var state: State = State.OFF

var warning_time: float = 1.0
var active_time: float = 1.5
var off_time: float = 2.0

var width: float = 600.0
var thickness: float = 15.0

var timer: float = 0.0
var visual: ColorRect
var area: Area2D
var collision: CollisionShape2D
var _flash_tween: Tween

const HORIZON_OFFSET: float = -200.0

func _ready() -> void:
	# Visual
	visual = ColorRect.new()
	visual.color = Color(0, 1, 1, 0) # Cyan, transparent initially
	visual.size = Vector2(width, thickness)
	visual.position = Vector2(-width/2, -thickness/2)
	add_child(visual)
	
	# Collision
	area = Area2D.new()
	collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, thickness)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	
	# Start with OFF state but wait for off_time to pass
	_set_state(State.OFF)
	area.body_entered.connect(_on_body_entered)

func setup(w: float, w_time: float = 1.0, a_time: float = 1.5, o_time: float = 2.0) -> void:
	width = w
	warning_time = w_time
	active_time = a_time
	off_time = o_time
	if visual:
		visual.size.x = width
		visual.position.x = -width/2
	if collision:
		collision.shape.size.x = width

func _set_state(new_state: State) -> void:
	state = new_state
	timer = 0.0
	
	if state == State.OFF:
		# Collision disabled
		collision.set_deferred("disabled", true)
		visual.color = Color(0, 1, 1, 0.1) # Barely visible outline
	
	elif state == State.WARNING:
		# Collision disabled
		collision.set_deferred("disabled", true)
		# Flash animation
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween().bind_node(self).set_loops()
		_flash_tween.tween_property(visual, "color", Color(1, 0, 1, 0.5), 0.2)
		_flash_tween.tween_property(visual, "color", Color(1, 0, 1, 0.1), 0.2)
		# Subtle warning sound could go here
		
	elif state == State.ACTIVE:
		# Collision enabled
		collision.set_deferred("disabled", false)
		visual.color = Color(0, 1, 1, 1.0) # Solid Cyan/Magenta mix

func _physics_process(delta: float) -> void:
	timer += delta
	
	if state == State.OFF:
		if timer >= off_time:
			_set_state(State.WARNING)
	elif state == State.WARNING:
		if timer >= warning_time:
			# Remove the flashing tween safely
			if _flash_tween and _flash_tween.is_valid():
				_flash_tween.kill()
			_set_state(State.ACTIVE)
	elif state == State.ACTIVE:
		if timer >= active_time:
			_set_state(State.OFF)

func _process(_delta: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if cam:
		var cam_y = cam.global_position.y
		var horizon_y = cam_y + HORIZON_OFFSET
		var dist = global_position.y - horizon_y
		
		# Simple depth scaling matching platform.gd
		var scale_factor = 1.0
		if dist > 0:
			var t = clamp(dist / 800.0, 0.0, 1.0)
			t = pow(t, 1.5)
			scale_factor = lerp(0.2, 1.8, t)
		else:
			scale_factor = 0.2
			
		scale = Vector2(scale_factor, scale_factor)
		
		# Cleanup if far behind camera
		if global_position.y > cam.get_bottom_world_y() + 500:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if state == State.ACTIVE and body.name == "Player":
		if body.has_method("die_with_reason"):
			body.die_with_reason("LASER HIT")
