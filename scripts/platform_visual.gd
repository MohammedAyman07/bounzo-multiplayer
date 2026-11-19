extends Node2D

var _width: float = 200.0
var _height: float = 22.0

# Neon style colors matching the reference
const COLOR_FILL      = Color(0.40, 0.05, 0.90, 1.0)  # Solid bright purple body
const COLOR_EDGE_TOP  = Color(1.00, 0.15, 0.95, 1.0)  # Very bright saturated pink edge
const COLOR_EDGE_SIDE = Color(0.60, 0.05, 0.80, 0.90) 
const COLOR_GLOW      = Color(1.00, 0.15, 0.95, 0.40) # Stronger pink glow
const COLOR_CORE      = Color(0.85, 0.20, 1.00, 0.70)


func setup(w: float, h: float) -> void:
	_width = w
	_height = h
	queue_redraw()


func _draw() -> void:
	var hw: float = _width * 0.5
	var hh: float = _height * 0.5

	# Trapezoid top to fake perspective (back edge is narrower)
	var narrow_factor: float = 0.95
	var top_hw: float = hw * narrow_factor

	var pts_top = PackedVector2Array([
		Vector2(-top_hw, -hh),
		Vector2(top_hw, -hh),
		Vector2(hw, 0),
		Vector2(-hw, 0)
	])
	draw_colored_polygon(pts_top, COLOR_FILL)
	
	# Inner core glow for the top face
	var pts_core = PackedVector2Array([
		Vector2(-top_hw + 10, -hh + 5),
		Vector2(top_hw - 10, -hh + 5),
		Vector2(hw - 15, -5),
		Vector2(-hw + 15, -5)
	])
	draw_colored_polygon(pts_core, COLOR_CORE)

	# Pseudo-3D front/bottom face
	var depth: float = 14.0
	var bottom_color = Color(0.20, 0.02, 0.40, 0.95)
	var pts_bottom = PackedVector2Array([
		Vector2(-hw, 0),
		Vector2(hw, 0),
		Vector2(hw - 6.0, depth),
		Vector2(-hw + 6.0, depth)
	])
	draw_colored_polygon(pts_bottom, bottom_color)

	# Neon top edge (front edge)
	draw_line(Vector2(-hw, 0), Vector2(hw, 0), COLOR_EDGE_TOP, 3.0)
	
	# Neon back edge
	draw_line(Vector2(-top_hw, -hh), Vector2(top_hw, -hh), COLOR_EDGE_TOP, 1.5)
	
	# Side edges
	draw_line(Vector2(-hw, 0), Vector2(-top_hw, -hh), COLOR_EDGE_TOP, 2.0)
	draw_line(Vector2(hw, 0), Vector2(top_hw, -hh), COLOR_EDGE_TOP, 2.0)

	# Bottom soft glow lines (fake shadow/glow)
	draw_line(Vector2(-hw, depth+4), Vector2(hw, depth+4), COLOR_GLOW, 12.0)
	draw_line(Vector2(-hw+10, depth+12), Vector2(hw-10, depth+12), Color(COLOR_GLOW, 0.4), 24.0)

	# Vertical side edges
	draw_line(Vector2(-hw, 0), Vector2(-hw + 6.0, depth), COLOR_EDGE_SIDE, 2.0)
	draw_line(Vector2(hw, 0), Vector2(hw - 6.0, depth), COLOR_EDGE_SIDE, 2.0)
