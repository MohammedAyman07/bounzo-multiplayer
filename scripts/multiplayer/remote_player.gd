class_name RemotePlayer
extends Node2D

# ==============================================================================
# REMOTE OPPONENT PRESENTATION
# Displays opponent with glowing neon trail, slot styling, and overhead nametag.
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")

var peer_id: int = 0
var slot_index: int = 0
var player_name: String = ""
var is_alive: bool = true
var target_position: Vector2 = Vector2(270.0, -200.0)

var trail_points: Array[Vector2] = []
var trail_max: int = 12

@onready var nametag: Label = $Nametag
@onready var nametag_panel: PanelContainer = $NametagPanel
@onready var panel_label: Label = $NametagPanel/Label

var _slot_color: Color = Color.WHITE

func setup(p_id: int, slot: int, p_name: String, _cosmetics: Dictionary = {}) -> void:
	peer_id = p_id
	slot_index = slot
	player_name = p_name

	if slot >= 0 and slot < Protocol.SLOT_COLORS.size():
		_slot_color = Protocol.SLOT_COLORS[slot]
	else:
		_slot_color = Color.WHITE

	if is_node_ready():
		_apply_visuals()

func _ready() -> void:
	_apply_visuals()

func _apply_visuals() -> void:
	if panel_label != null:
		panel_label.text = player_name
		panel_label.modulate = _slot_color
	elif nametag != null:
		nametag.text = player_name
		nametag.modulate = _slot_color
	queue_redraw()

func update_network_state(x: float, y: float, alive: bool) -> void:
	target_position = Vector2(x, y)
	if is_alive and not alive:
		is_alive = false
		_on_eliminated()
	elif not is_alive and alive:
		is_alive = true
		modulate.a = 1.0
		_apply_visuals()

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, 18.0 * delta)

	# Update trail points in local space
	trail_points.push_front(global_position)
	if trail_points.size() > trail_max:
		trail_points.pop_back()

	queue_redraw()

func _on_eliminated() -> void:
	modulate.a = 0.4
	if panel_label != null:
		panel_label.text = "%s (OUT)" % player_name
	elif nametag != null:
		nametag.text = "%s (OUT)" % player_name

func _draw() -> void:
	# Draw glowing trail
	if trail_points.size() > 1:
		for i in range(trail_points.size() - 1):
			var p1 = to_local(trail_points[i])
			var p2 = to_local(trail_points[i + 1])
			var t_ratio = 1.0 - (float(i) / float(trail_max))
			var w = lerp(2.0, 10.0, t_ratio)
			var col = Color(_slot_color.r, _slot_color.g, _slot_color.b, t_ratio * 0.4)
			draw_line(p1, p2, col, w)

	# Draw glowing outer ring
	var glow_col = Color(_slot_color.r, _slot_color.g, _slot_color.b, 0.35)
	draw_circle(Vector2.ZERO, 22.0, glow_col)
	# Draw colored slot ring
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, _slot_color, 3.5, true)
	# Draw inner core
	draw_circle(Vector2.ZERO, 13.0, Color(0.06, 0.04, 0.12, 0.95))
	draw_circle(Vector2.ZERO, 8.0, _slot_color)
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
