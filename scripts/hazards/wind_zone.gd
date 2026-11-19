extends Node2D

var width: float = 600.0
var height: float = 400.0
var wind_force: float = 0.0 # Positive for right, negative for left

var area: Area2D
var collision: CollisionShape2D
var visual_particles: CPUParticles2D

const HORIZON_OFFSET: float = -200.0

func _ready() -> void:
	area = Area2D.new()
	collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	# Lightweight particles
	visual_particles = CPUParticles2D.new()
	visual_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	visual_particles.emission_rect_extents = Vector2(width/2, height/2)
	visual_particles.amount = 30
	visual_particles.lifetime = 1.0
	visual_particles.gravity = Vector2(0, 0)
	
	# Depending on force direction, set particle velocity
	if wind_force > 0:
		visual_particles.direction = Vector2(1, 0)
		visual_particles.color = Color(0.2, 0.8, 1.0, 0.4)
	else:
		visual_particles.direction = Vector2(-1, 0)
		visual_particles.color = Color(1.0, 0.2, 0.8, 0.4)
		
	visual_particles.spread = 10.0
	visual_particles.initial_velocity_min = abs(wind_force) * 0.5
	visual_particles.initial_velocity_max = abs(wind_force)
	visual_particles.scale_amount_min = 2.0
	visual_particles.scale_amount_max = 5.0
	add_child(visual_particles)

func setup(w: float, h: float, force: float) -> void:
	width = w
	height = h
	wind_force = force

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
		
		if global_position.y > cam.get_bottom_world_y() + max(height, 500.0):
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("add_wind_zone"):
		body.add_wind_zone(self, wind_force)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("remove_wind_zone"):
		body.remove_wind_zone(self)
