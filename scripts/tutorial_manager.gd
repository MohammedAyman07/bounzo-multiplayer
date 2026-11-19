extends Node
class_name TutorialManager

enum TState { INACTIVE, INTRO, MOVE }

var state: TState = TState.INACTIVE
var game: Node = null

var ui_layer: CanvasLayer
var panel: Panel
var title_lbl: Label
var desc_lbl: Label
var skip_btn: Button
var hand_icon: Label
var glow_rect: ColorRect

var target_plat = null
var step_completed = false
var tutorial_plats = []
var hand_tw: Tween

func setup(g: Node) -> void:
	game = g
	name = "TutorialManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	ui_layer.hide()
	add_child(ui_layer)
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(dim)
	
	panel = Panel.new()
	panel.size = Vector2(460, 160)
	panel.position.y = 50
	panel.position.x = (game.VIEWPORT_W - 460) / 2
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.2, 1, 1, 1)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(panel)
	
	title_lbl = Label.new()
	title_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position.y = 10
	if Engine.has_singleton("UITheme"):
		title_lbl.label_settings = get_node("/root/UITheme").ls(24, get_node("/root/UITheme").CYAN)
	panel.add_child(title_lbl)
	
	desc_lbl = Label.new()
	desc_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.position.y = -90
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if Engine.has_singleton("UITheme"):
		desc_lbl.label_settings = get_node("/root/UITheme").ls(16, Color.WHITE)
	panel.add_child(desc_lbl)
	
	skip_btn = Button.new()
	skip_btn.text = "SKIP"
	skip_btn.position = Vector2(game.VIEWPORT_W - 80, 40)
	skip_btn.pressed.connect(_on_skip_pressed)
	ui_layer.add_child(skip_btn)
	
	hand_icon = Label.new()
	hand_icon.text = "👆"
	var hand_ls = LabelSettings.new()
	hand_ls.font_size = 100
	hand_icon.label_settings = hand_ls
	game.add_child(hand_icon)
	hand_icon.hide()

func is_active() -> bool:
	return state != TState.INACTIVE

func start_tutorial() -> void:
	SaveManager.data["first_time_tutorial_completed"] = false
	state = TState.INTRO
	ui_layer.show()
	_set_state(TState.MOVE)

func _spawn_tut_plat(pos: Vector2, p_type: int = 0) -> Node:
	var p = preload("res://scenes/platform/platform.tscn").instantiate()
	game.platform_gen.add_child(p)
	p.global_position = pos
	p.setup(200.0, 22.0, p_type, 0.0, 0.0, 0)
	return p

func _set_state(new_state: TState) -> void:
	state = new_state
	step_completed = false
	waiting_for_tap = false
	is_forced_jumping = false
	get_tree().paused = false
	hand_icon.hide()
	
	game.player.revive()
	game.player.velocity = Vector2.ZERO
	game.player.global_position = Vector2(game.VIEWPORT_W / 2, game.camera.global_position.y - 200)
	game.platform_gen.clear_all()
	
	var base_y = game.player.global_position.y + 100
	tutorial_plats.clear()
	var p0 = _spawn_tut_plat(Vector2(game.VIEWPORT_W / 2, base_y)) # starting platform
	tutorial_plats.append(p0)
	target_plat = null
	
	match state:
		TState.MOVE:
			title_lbl.text = "HOW TO PLAY"
			desc_lbl.text = "Tap left or right to jump across the platforms!"
			hand_icon.show()
			game.player.velocity.y = -200
			
			step_progress = 0
			var cur_y = base_y
			for i in range(10):
				cur_y -= 150
				var offset = 130 if i % 2 == 0 else -130
				var p = _spawn_tut_plat(Vector2(game.VIEWPORT_W / 2 + offset, cur_y))
				tutorial_plats.append(p)
				
			_update_hand_animation()

func _update_hand_animation() -> void:
	if hand_tw:
		hand_tw.kill()
		hand_tw = null
		
	var target_idx = step_progress
	if step_progress == 0:
		target_idx = 1
		
	if target_idx >= tutorial_plats.size():
		hand_icon.hide()
		return
		
	var next_p = tutorial_plats[target_idx]
	hand_icon.show()
	hand_icon.text = "👆"
	
	# Position the hand directly below the target platform in world space
	var center_x = next_p.global_position.x - 50 # adjust for font width
	var base_y = next_p.global_position.y + 20
	
	hand_icon.global_position = Vector2(center_x, base_y)
	
	hand_tw = create_tween().set_loops()
	hand_tw.tween_property(hand_icon, "global_position:y", base_y + 30, 0.3).set_trans(Tween.TRANS_QUAD)
	hand_tw.tween_property(hand_icon, "global_position:y", base_y, 0.3).set_trans(Tween.TRANS_QUAD)
	hand_tw.tween_interval(0.2)

func _process(delta: float) -> void:
	if state == TState.INACTIVE or step_completed: return
	
	if is_forced_jumping:
		game.player.velocity.x = forced_vx
	
	if game.player.global_position.y > game.camera.get_bottom_world_y() + 50 or not game.player.is_alive:
		_set_state(state)
		return

var step_progress = 0
var waiting_for_tap = false
var forced_vx = 0.0
var is_forced_jumping = false

func on_player_bounce(platform) -> void:
	if state == TState.INACTIVE or step_completed: return
	
	match state:
		TState.MOVE:
			is_forced_jumping = false
			step_progress += 1
			if step_progress >= 5:
				_success("PERFECT!")
			else:
				_update_hand_animation()
				get_tree().paused = true
				waiting_for_tap = true

func _unhandled_input(event: InputEvent) -> void:
	if state == TState.MOVE:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			get_viewport().set_input_as_handled()
			
		if waiting_for_tap and event is InputEventScreenTouch and event.pressed:
			var is_left = event.position.x < (game.VIEWPORT_W / 2)
			
			var target_idx = step_progress
			if step_progress == 0: target_idx = 1
			if target_idx >= tutorial_plats.size(): return
			
			var next_p = tutorial_plats[target_idx]
			var platform_is_left = next_p.global_position.x < game.VIEWPORT_W / 2
			
			if is_left == platform_is_left:
				waiting_for_tap = false
				get_tree().paused = false
				hand_icon.hide()
				if hand_tw:
					hand_tw.kill()
					hand_tw = null
					
				# Calculate perfect physics trajectory!
				var dx = next_p.global_position.x - game.player.global_position.x
				var grav = game.player.gravity
				var bounce = abs(game.player.bounce_force)
				
				var t_up = bounce / grav
				var peak_y = game.player.global_position.y - (bounce * bounce) / (2.0 * grav)
				var fall_dist = next_p.global_position.y - peak_y
				
				var t_down = 0.0
				if fall_dist > 0:
					t_down = sqrt(2.0 * fall_dist / grav)
				
				var total_time = t_up + t_down
				if total_time > 0:
					forced_vx = dx / total_time
					is_forced_jumping = true

func _success(msg: String) -> void:
	step_completed = true
	var lbl = Label.new()
	lbl.text = msg
	if Engine.has_singleton("UITheme"):
		lbl.label_settings = get_node("/root/UITheme").ls(32, get_node("/root/UITheme").YELLOW)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	ui_layer.add_child(lbl)
	var t = create_tween()
	t.tween_property(lbl, "position:y", -100, 1.0).as_relative()
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	t.tween_callback(lbl.queue_free)
	t.tween_callback(_complete_tutorial)

func _on_skip_pressed() -> void:
	var d = ConfirmationDialog.new()
	d.title = "Skip Tutorial?"
	d.dialog_text = "You can replay it later from Settings -> How to Play."
	d.ok_button_text = "Skip"
	d.cancel_button_text = "Continue"
	d.confirmed.connect(func():
		_complete_tutorial()
		d.queue_free()
	)
	d.canceled.connect(func():
		d.queue_free()
	)
	ui_layer.add_child(d)
	d.popup_centered()

func _complete_tutorial() -> void:
	SaveManager.data["first_time_tutorial_completed"] = true
	SaveManager.save_data()
	state = TState.INACTIVE
	ui_layer.hide()
	hand_icon.hide()
	if hand_tw:
		hand_tw.kill()
		hand_tw = null
	game._start_game()
