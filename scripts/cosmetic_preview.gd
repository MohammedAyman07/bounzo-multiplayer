extends Control
class_name CosmeticPreview

# =====================================================
# COSMETIC PREVIEW — Procedural Energy Orbs
# =====================================================

enum Type { BASIC, FIRE, LIGHTNING, CRYSTAL, SHADOW, NEON }

@export var type: Type = Type.BASIC:
	set(v):
		type = v
		if is_inside_tree():
			_update_visuals()

var _particles: CPUParticles2D
var _core_color: Color
var _glow_color: Color
var _accent_color: Color

func _init(t: Type = Type.BASIC) -> void:
	type = t
	custom_minimum_size = Vector2(100, 100)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER

func _ready() -> void:
	_particles = CPUParticles2D.new()
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 20.0
	_particles.direction = Vector2.ZERO
	_particles.spread = 180.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 10.0
	_particles.initial_velocity_max = 30.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 5.0
	_particles.lifetime = 1.2
	_particles.amount = 30
	_particles.position = size / 2.0
	add_child(_particles)
	
	_update_visuals()

func _update_visuals() -> void:
	match type:
		Type.BASIC:
			_core_color = Color(0.6, 0.9, 1.0)
			_glow_color = Color(0.1, 0.5, 1.0, 0.6)
			_accent_color = Color(0.2, 0.8, 1.0)
			
		Type.FIRE:
			_core_color = Color(1.0, 0.9, 0.2)
			_glow_color = Color(1.0, 0.3, 0.0, 0.7)
			_accent_color = Color(1.0, 0.6, 0.0)
			
		Type.LIGHTNING:
			_core_color = Color(1.0, 1.0, 1.0)
			_glow_color = Color(0.0, 0.3, 1.0, 0.8)
			_accent_color = Color(1.0, 0.9, 0.2)
			
		Type.CRYSTAL:
			_core_color = Color(0.8, 0.9, 1.0)
			_glow_color = Color(0.6, 0.2, 1.0, 0.6)
			_accent_color = Color(0.9, 0.4, 1.0)
			
		Type.SHADOW:
			_core_color = Color(0.2, 0.0, 0.4)
			_glow_color = Color(0.4, 0.0, 0.8, 0.8)
			_accent_color = Color(0.1, 0.0, 0.2)
			
		Type.NEON:
			_core_color = Color(1.0, 1.0, 1.0)
			_glow_color = Color(1.0, 0.2, 0.8, 0.7)
			_accent_color = Color(0.2, 1.0, 0.8)

	_particles.color = _accent_color
	queue_redraw()

func _process(delta: float) -> void:
	if type == Type.NEON:
		var hue = wrapf(Time.get_ticks_msec() / 2000.0, 0.0, 1.0)
		_glow_color = Color.from_hsv(hue, 0.8, 1.0, 0.7)
		_accent_color = Color.from_hsv(wrapf(hue + 0.3, 0.0, 1.0), 0.8, 1.0)
		_particles.color = _accent_color
		queue_redraw()
	elif type == Type.LIGHTNING:
		if randf() < 0.05:
			queue_redraw()
	elif type == Type.SHADOW:
		_core_color = _core_color.lerp(Color(0.1, 0.0, 0.2), 0.1)
		if randf() < 0.02:
			_core_color = Color(0.5, 0.2, 0.8)
		queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	var r = size.x * 0.35
	
	# Outer glow
	draw_circle(center, r * 1.5, _glow_color)
	draw_circle(center, r * 1.2, _glow_color.lerp(Color.WHITE, 0.2))
	
	# Main Core
	draw_circle(center, r, _core_color)
	
	# Details
	if type == Type.LIGHTNING:
		for i in range(4):
			var a = randf() * PI * 2
			var p2 = center + Vector2(cos(a), sin(a)) * (r * 1.6)
			draw_line(center, p2, _accent_color, 2.0, true)
	
	if type == Type.CRYSTAL:
		var pts = PackedVector2Array()
		for i in range(6):
			var a = i * PI / 3.0
			pts.append(center + Vector2(cos(a), sin(a)) * (r * 1.2))
		draw_polygon(pts, PackedColorArray([_accent_color, _accent_color, _accent_color, _accent_color, _accent_color, _accent_color]))
		draw_circle(center, r * 0.8, _core_color)
		
	# Specular highlight
	draw_circle(center + Vector2(-r * 0.3, -r * 0.3), r * 0.2, Color(1, 1, 1, 0.6))
