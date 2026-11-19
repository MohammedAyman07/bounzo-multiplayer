extends TextureRect

func _ready() -> void:
	get_tree().root.size_changed.connect(_update_size)
	_update_size()

func _update_size() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	var window_size = DisplayServer.window_get_size()
	
	var w = 0.0
	if window_size.x > 0 and safe_area.size.x > 0:
		var vp_size = get_viewport().get_visible_rect().size
		var scale_x = vp_size.x / float(window_size.x)
		var actual_safe_w = min(safe_area.size.x, window_size.x)
		w = actual_safe_w * scale_x
	else:
		w = get_viewport().get_visible_rect().size.x
		if w == 0:
			w = 540.0 # safe fallback
			
	var w_pct = 0.75
	if w <= 375:
		w_pct = 0.85
	elif w <= 430:
		w_pct = 0.82
	else:
		w_pct = 0.75
		
	var target_w = w * w_pct
	
	# Clamp to sensible sizes based on screen height so it doesn't push UI off-screen
	var max_h = get_viewport().get_visible_rect().size.y * 0.30
	target_w = clamp(target_w, 150.0, max(150.0, max_h))
	
	custom_minimum_size = Vector2(target_w, target_w)
