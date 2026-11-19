extends MarginContainer

func _ready() -> void:
	get_tree().root.size_changed.connect(_update_safe_area)
	_update_safe_area()

func _update_safe_area() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	var window_size = DisplayServer.window_get_size()
	
	if window_size.x == 0 or window_size.y == 0:
		return
		
	var vp_size = get_viewport().get_visible_rect().size
	var scale_x = vp_size.x / float(window_size.x)
	var scale_y = vp_size.y / float(window_size.y)
	
	var safe_w = min(safe_area.size.x, window_size.x)
	var safe_h = min(safe_area.size.y, window_size.y)
	
	# If on desktop, the safe area position might be monitor-relative, while window size is window-relative.
	# The most reliable way for cross-platform is just to use safe_area if it's smaller than the window,
	# but for margins, we should calculate the difference.
	# Actually, if window_size.x <= safe_area.size.x, we are likely not full screen or on desktop.
	var is_desktop = window_size.x < safe_area.size.x or window_size.y < safe_area.size.y
	
	var left = 0.0
	var top = 0.0
	var right = 0.0
	var bottom = 0.0
	
	if not is_desktop:
		left = safe_area.position.x * scale_x
		top = safe_area.position.y * scale_y
		right = (window_size.x - (safe_area.position.x + safe_w)) * scale_x
		bottom = (window_size.y - (safe_area.position.y + safe_h)) * scale_y
	
	left = max(0, left)
	top = max(0, top)
	right = max(0, right)
	bottom = max(0, bottom)
	
	add_theme_constant_override("margin_left", int(left))
	add_theme_constant_override("margin_top", int(top))
	add_theme_constant_override("margin_right", int(right))
	add_theme_constant_override("margin_bottom", int(bottom))
