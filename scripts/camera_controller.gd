extends Camera2D

# Where the player appears vertically (0.0=top, 1.0=bottom)
# 0.75 = player at 75% from top, pushing it lower
@export var player_screen_position: float = 0.75

# Lerp speed (higher = snappier)
@export var lerp_speed: float = 4.5

var _target_node: Node2D = null
var _highest_y: float = 0.0
var _initialized: bool = false
var _viewport_height: float = 960.0


func setup(target: Node2D, viewport_h: float) -> void:
	_target_node = target
	_viewport_height = viewport_h
	reset()


func reset() -> void:
	if _target_node:
		var desired_y := _get_desired_y()
		global_position.y = desired_y
		_highest_y = desired_y
		_initialized = true


func _process(delta: float) -> void:
	if not _initialized or not is_instance_valid(_target_node):
		return

	var desired_y := _get_desired_y()

	# Ratchet: only follow upward (camera Y only decreases)
	_highest_y = min(_highest_y, desired_y)

	# Smooth lerp
	global_position.y = lerp(global_position.y, _highest_y, lerp_speed * delta)


# Camera Y so player appears at player_screen_position from top
func _get_desired_y() -> float:
	if not _target_node:
		return 0.0
	# cam_y = player.y - viewport_h * (player_screen_position - 0.5)
	# e.g. 0.70 -> cam_y = player.y - 192  -> player at 672/960 = 70% from top
	return _target_node.global_position.y - _viewport_height * (player_screen_position - 0.5)


func get_bottom_world_y() -> float:
	return global_position.y + _viewport_height * 0.5


func get_top_world_y() -> float:
	return global_position.y - _viewport_height * 0.5
