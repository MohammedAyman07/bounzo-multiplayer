extends CharacterBody2D

# CONFIGURABLE PHYSICS VARIABLES
@export var horizontal_speed: float = 380.0
@export var max_horizontal_speed: float = 500.0
@export var horizontal_acceleration: float = 1800.0
@export var gravity: float = 1400.0
@export var bounce_force: float = -760.0
@export var terminal_velocity: float = 1200.0

# SIGNALS
signal landed_on_platform(platform_body: Node)
signal fell_below_death_zone
signal player_died

# INTERNAL STATE
var move_direction: float = 0.0
var is_alive: bool = true
var platform_scored: Dictionary = {}

@onready var visual = $PlayerVisual
const HORIZON_OFFSET: float = -200.0


func _ready() -> void:
	up_direction = Vector2.UP
	floor_stop_on_slope = false
	floor_snap_length = 8.0


func _physics_process(delta: float) -> void:
	if not is_alive:
		# Fall naturally when dead
		velocity.y += gravity * delta
		var w_force = get_total_wind_force()
		velocity.x = move_toward(velocity.x, w_force, 100.0 * delta)
		move_and_slide()
		return

	# Apply Wind
	var total_wind = get_total_wind_force()
	
	# Horizontal movement
	var target_vx: float = (move_direction * horizontal_speed) + total_wind
	
	if move_direction != 0.0:
		velocity.x = move_toward(velocity.x, target_vx, horizontal_acceleration * delta)
	else:
		# When no input, drift towards wind speed, not 0
		velocity.x = move_toward(velocity.x, total_wind, horizontal_acceleration * 0.5 * delta)
	
	# Clamp horizontal speed, but allow wind to push past the normal limit slightly
	var effective_max_speed = max_horizontal_speed
	if total_wind != 0.0 and sign(velocity.x) == sign(total_wind):
		effective_max_speed += abs(total_wind)
		
	velocity.x = clamp(velocity.x, -effective_max_speed, effective_max_speed)

	# Track falling state BEFORE move so check is reliable after collision response
	var was_falling: bool = velocity.y >= 0.0

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, terminal_velocity)

	# Move
	move_and_slide()

	# Bounce on landing
	if is_on_floor() and was_falling:
		_do_bounce()
		if visual:
			visual.emit_landing_burst()
			
		for i in get_slide_collision_count():
			var collider = get_slide_collision(i)
			if collider:
				var body = collider.get_collider()
				if body and not platform_scored.has(body.get_instance_id()):
					platform_scored[body.get_instance_id()] = true
					landed_on_platform.emit(body)
					if body.has_method("crack"):
						body.crack()
					if body.has_method("trigger_shrink"):
						body.trigger_shrink()
					if body.has_method("trigger_vanish"):
						body.trigger_vanish()

	# Update visual trail
	if visual and visual.has_method("update_trail"):
		visual.update_trail(global_position)
		
	# Raycast for shadow
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.DOWN * 1500.0)
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		if visual and visual.has_method("update_shadow"):
			visual.update_shadow(result.position.y - global_position.y)
	else:
		if visual and visual.has_method("update_shadow"):
			visual.update_shadow(-1.0)


func _process(_delta: float) -> void:
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
		# Keep visual bottom aligned with physics bottom (radius 13)
		visual.position.y = 13.0 * (1.0 - scale_factor)


func _do_bounce() -> void:
	velocity.y = bounce_force


func set_direction(dir: float) -> void:
	move_direction = dir


func reset(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	move_direction = 0.0
	is_alive = true
	platform_scored.clear()
	if visual:
		visual._load_cosmetics()
		visual.clear_trail()


var death_reason: String = ""

var active_wind_zones: Dictionary = {}

func add_wind_zone(zone: Node, force: float) -> void:
	active_wind_zones[zone.get_instance_id()] = force

func remove_wind_zone(zone: Node) -> void:
	active_wind_zones.erase(zone.get_instance_id())

func get_total_wind_force() -> float:
	var total: float = 0.0
	for force in active_wind_zones.values():
		total += force
	return total

func die() -> void:
	if not is_alive: return
	is_alive = false
	player_died.emit()

func revive() -> void:
	is_alive = true
	velocity = Vector2.ZERO
	move_direction = 0.0
	if visual:
		visual.clear_trail()

func die_with_reason(reason: String) -> void:
	death_reason = reason
	die()
