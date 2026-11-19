extends Control
# =====================================================
# SETTINGS UI — Premium Redesign
# Follows the same pattern as Shop/Daily/Missions.
# =====================================================
var _music_toggle: Button
var _music_slider: HSlider
var _sfx_toggle: Button
var _sfx_slider: HSlider
var _vib_toggle: Button
var _reset_confirm: Control
var _about_panel: Control

func _ready() -> void:
	name = "SettingsPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport_rect().size)
	_build_ui()
	SettingsManager.settings_changed.connect(_refresh_ui)
	_refresh_ui()  

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(UITheme.BG, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)
	# â”€â”€ HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	var hdr_m = MarginContainer.new()
	hdr_m.add_theme_constant_override("margin_left",  20)
	hdr_m.add_theme_constant_override("margin_right", 20)
	hdr_m.add_theme_constant_override("margin_top",   20)
	hdr_m.add_theme_constant_override("margin_bottom", 20)
	root_vbox.add_child(hdr_m)
	var header = UITheme.make_header("SETTINGS", true, false, func():
		AudioManager.play(AudioManager.SND_BUTTON)
		hide()
		var ui = get_parent()
		var is_paused = false
		if ui and ui.get_parent():
			var game = ui.get_parent()
			if "_state" in game and "State" in game:
				is_paused = (game.get("_state") == game.State.PAUSED)
				
		if is_paused and ui and ui.has_node("PausePanel"):
			ui.get_node("PausePanel").show()
		elif ui and ui.has_node("MainMenuPanel"):
			ui.get_node("MainMenuPanel").show()
	)
	hdr_m.add_child(header)
	# â”€â”€ SCROLL AREA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)
	var content_m = MarginContainer.new()
	content_m.add_theme_constant_override("margin_left",  24)
	content_m.add_theme_constant_override("margin_right", 24)
	content_m.add_theme_constant_override("margin_top",   20)
	content_m.add_theme_constant_override("margin_bottom",24)
	content_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_m)
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "SettingsContentVBox"
	content_vbox.add_theme_constant_override("separation", 24)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_m.add_child(content_vbox)
	# â”€â”€ SECTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	
	# AUDIO
	var audio_card = _make_section_card("AUDIO")
	content_vbox.add_child(audio_card)
	var audio_vb = audio_card.get_node("Margin/VBox")
	
	_music_toggle = _make_toggle_row(audio_vb, "MUSIC", UIIcon.Type.PLAY, _on_music_toggled)
	_music_slider = _make_slider_row(audio_vb, _on_music_slider)
	
	audio_vb.add_child(_make_divider())
	
	_sfx_toggle = _make_toggle_row(audio_vb, "SOUND EFFECTS", UIIcon.Type.PAUSE, _on_sfx_toggled) # Pause icon used as general 'sound' icon placeholder if no speaker exists
	_sfx_slider = _make_slider_row(audio_vb, _on_sfx_slider)
	# GAMEPLAY
	var gp_card = _make_section_card("GAMEPLAY")
	content_vbox.add_child(gp_card)
	var gp_vb = gp_card.get_node("Margin/VBox")
	
	_make_action_row(gp_vb, "HOW TO PLAY", UITheme.CYAN, _on_how_to_play_clicked)
	gp_vb.add_child(_make_divider())
	
	_vib_toggle = _make_toggle_row(gp_vb, "VIBRATION", UIIcon.Type.SETTINGS, _on_vib_toggled)
	# SYSTEM
	var sys_card = _make_section_card("SYSTEM")
	content_vbox.add_child(sys_card)
	var sys_vb = sys_card.get_node("Margin/VBox")
	

	var about_btn = _make_action_row(sys_vb, "ABOUT", UITheme.WHITE, _on_about_clicked)
	_build_reset_modal()
	_build_about_modal() 
# â”€â”€ UI Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ 

func _make_section_card(title: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", UITheme.glass_panel(UITheme.RADIUS_LG))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var m = MarginContainer.new()
	m.name = "Margin"
	m.add_theme_constant_override("margin_left",  20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top",   24)
	m.add_theme_constant_override("margin_bottom",24)
	card.add_child(m)
	
	var vb = VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 16)
	m.add_child(vb)
	
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.label_settings = UITheme.ls(14, UITheme.MUTED)
	vb.add_child(title_lbl)
	
	return card  

func _make_divider() -> Control:
	var div = PanelContainer.new()
	div.custom_minimum_size = Vector2(0, 1)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	div.add_theme_stylebox_override("panel", sb)
	return div  

func _make_toggle_row(parent: Control, text: String, icon_type: int, callback: Callable) -> Button:
	var hb = HBoxContainer.new()
	parent.add_child(hb)
	
	var lbl = Label.new()
	lbl.text = text
	lbl.label_settings = UITheme.ls_heading()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lbl)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(60, 30)
	btn.focus_mode = Control.FOCUS_NONE
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.2, 0.2, 0.25)
	sb_normal.set_corner_radius_all(15)
	var sb_pressed = sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.15, 0.15, 0.2)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_normal)
	
	var fill = Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = UITheme.CYAN
	fsb.set_corner_radius_all(15)
	fsb.shadow_color = Color(UITheme.CYAN, 0.4)
	fsb.shadow_size = 6
	fill.add_theme_stylebox_override("panel", fsb)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_right = 0
# Will be animated
	btn.add_child(fill)
	
	var knob = Panel.new()
	knob.name = "Knob"
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ksb = StyleBoxFlat.new()
	ksb.bg_color = Color.WHITE
	ksb.set_corner_radius_all(12)
	ksb.shadow_color = Color(0,0,0, 0.5)
	ksb.shadow_size = 4
	knob.add_theme_stylebox_override("panel", ksb)
	knob.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	knob.offset_left = 3
	knob.offset_top = 3
	knob.offset_bottom = -3
	knob.offset_right = 27
	btn.add_child(knob)
	
	var lbl_onoff = Label.new()
	lbl_onoff.name = "Status"
	lbl_onoff.text = "ON"
	lbl_onoff.label_settings = UITheme.ls_title_font(12, Color.WHITE)
	lbl_onoff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_onoff.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_onoff.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(lbl_onoff)
	
	btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		callback.call()
	)
	hb.add_child(btn)
	
	return btn  

func _make_slider_row(parent: Control, callback: Callable) -> HSlider:
	var slider = HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 30)
	
	# Custom slider styling
	var s_bg = StyleBoxFlat.new()
	s_bg.bg_color = Color(0.1, 0.05, 0.15)
	s_bg.set_corner_radius_all(6)
	s_bg.expand_margin_top = 8
	s_bg.expand_margin_bottom = 8
	slider.add_theme_stylebox_override("slider", s_bg)
	
	var s_fill = StyleBoxFlat.new()
	s_fill.bg_color = UITheme.CYAN
	s_fill.set_corner_radius_all(6)
	s_fill.expand_margin_top = 8
	s_fill.expand_margin_bottom = 8
	slider.add_theme_stylebox_override("grabber_area", s_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", s_fill)
	
	# Create a dummy image for grabber to hide default
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var tex = ImageTexture.create_from_image(img)
	slider.add_theme_icon_override("grabber", tex)
	slider.add_theme_icon_override("grabber_highlight", tex)
	
	# Add custom grabber visual
	var grabber_vis = Panel.new()
	grabber_vis.name = "CustomGrabber"
	grabber_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grabber_vis.custom_minimum_size = Vector2(20, 20)
	grabber_vis.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	grabber_vis.offset_top = -10
	grabber_vis.offset_bottom = 10
	var g_sb = StyleBoxFlat.new()
	g_sb.bg_color = Color.WHITE
	g_sb.set_corner_radius_all(10)
	g_sb.shadow_color = Color(UITheme.CYAN, 0.5)
	g_sb.shadow_size = 6
	grabber_vis.add_theme_stylebox_override("panel", g_sb)
	slider.add_child(grabber_vis)
	
	var val_lbl = Label.new()
	val_lbl.name = "ValueLabel"
	val_lbl.label_settings = UITheme.ls(14, UITheme.CYAN)
	val_lbl.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	val_lbl.position = Vector2(0, -25)
	slider.add_child(val_lbl)
	
	var update_visuals = func(v: float):
		if slider.size.x == 0: return
		var ratio = v / slider.max_value
		grabber_vis.position.x = ratio * (slider.size.x - 20)
		val_lbl.text = str(int(v * 100)) + "%"
		val_lbl.position.x = grabber_vis.position.x - 10
	slider.value_changed.connect(func(v):
		update_visuals.call(v)
		callback.call(v)
	)
	
	slider.resized.connect(func():
		update_visuals.call(slider.value)
	)
	
	# Call it deferred just in case to initialize position properly
	slider.ready.connect(func():
		update_visuals.call(slider.value)
	)
	
	parent.add_child(slider)
	return slider  

func _make_action_row(parent: Control, text: String, color: Color, callback: Callable) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	
	var hb = HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)
	
	var lbl = Label.new()
	lbl.text = text
	lbl.label_settings = UITheme.ls_heading()
	if color != UITheme.WHITE:
		lbl.label_settings = UITheme.ls_heading()
		lbl.label_settings.font_color = color
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lbl)
	
	var arrow = Label.new()
	arrow.text = ">"
	arrow.label_settings = UITheme.ls(20, Color(0.5, 0.5, 0.5))
	hb.add_child(arrow)
	
	btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		callback.call()
	)
	parent.add_child(btn)
	return btn 
# â”€â”€ State binding â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ 

func _on_music_toggled() -> void:
	SettingsManager.set_music_enabled(not SettingsManager.music_enabled) 

func _on_music_slider(val: float) -> void:
	SettingsManager.set_music_volume(val) 

func _on_sfx_toggled() -> void:
	SettingsManager.set_sfx_enabled(not SettingsManager.sfx_enabled)
	if SettingsManager.sfx_enabled:
		AudioManager.play(AudioManager.SND_BUTTON) 

func _on_sfx_slider(val: float) -> void:
	SettingsManager.set_sfx_volume(val) 

func _on_vib_toggled() -> void:
	SettingsManager.set_vibration_enabled(not SettingsManager.vibration_enabled)
	if SettingsManager.vibration_enabled:
		AudioManager.vibrate_light()  

func _refresh_ui() -> void:
	if not is_instance_valid(_music_toggle): return
	
	_update_toggle_visuals(_music_toggle, SettingsManager.music_enabled)
	_update_toggle_visuals(_sfx_toggle, SettingsManager.sfx_enabled)
	_update_toggle_visuals(_vib_toggle, SettingsManager.vibration_enabled)
	
	# Only update slider values if they aren't actively being dragged
	# to avoid fighting the user. (For simplicity here, just set them).
	_music_slider.set_value_no_signal(SettingsManager.music_volume)
	_music_slider.emit_signal("value_changed", SettingsManager.music_volume) # Force visual update
	
	_sfx_slider.set_value_no_signal(SettingsManager.sfx_volume)
	_sfx_slider.emit_signal("value_changed", SettingsManager.sfx_volume)  

func _update_toggle_visuals(btn: Button, is_on: bool) -> void:
	var fill = btn.get_node("Fill")
	var knob = btn.get_node("Knob")
	var status = btn.get_node("Status")
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	if is_on:
		tween.tween_property(fill, "anchor_right", 1.0, 0.15)
		tween.tween_property(knob, "anchor_left", 1.0, 0.15)
		tween.tween_property(knob, "anchor_right", 1.0, 0.15)
		tween.tween_property(knob, "offset_left", -27, 0.15)
		tween.tween_property(knob, "offset_right", -3, 0.15)
		status.text = "ON"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status.position.x = 10
	else:
		tween.tween_property(fill, "anchor_right", 0.0, 0.15)
		tween.tween_property(knob, "anchor_left", 0.0, 0.15)
		tween.tween_property(knob, "anchor_right", 0.0, 0.15)
		tween.tween_property(knob, "offset_left", 3, 0.15)
		tween.tween_property(knob, "offset_right", 27, 0.15)
		status.text = "OFF"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status.position.x = -10 
# â”€â”€ Modals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ 

func _build_reset_modal() -> void:
	_reset_confirm = ColorRect.new()
	_reset_confirm.color = Color(0, 0, 0, 0.9)
	_reset_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_confirm.hide()
	add_child(_reset_confirm)
	
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_confirm.add_child(cc)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	card.add_theme_stylebox_override("panel", UITheme.glass_panel(UITheme.RADIUS_LG))
	cc.add_child(card)
	
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 32)
	m.add_theme_constant_override("margin_bottom", 32)
	card.add_child(m)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	m.add_child(vb)
	
	var lbl = Label.new()
	lbl.text = "RESET ALL PROGRESS?"
	lbl.label_settings = UITheme.ls_title_font(20, UITheme.MAGENTA)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)
	
	var desc = Label.new()
	desc.text = "This will delete all coins, scores, cosmetics, and challenges.\n\nThis cannot be undone."
	desc.label_settings = UITheme.ls(14, UITheme.MUTED)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)
	
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(100, 44)
	cancel_btn.add_theme_stylebox_override("normal", UITheme.btn_primary(UITheme.RADIUS_MD))
	cancel_btn.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed())
	hb.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "RESET"
	confirm_btn.custom_minimum_size = Vector2(100, 44)
	var r_sb = StyleBoxFlat.new()
	r_sb.bg_color = UITheme.MAGENTA.darkened(0.5)
	r_sb.border_color = UITheme.MAGENTA
	r_sb.set_border_width_all(2)
	r_sb.set_corner_radius_all(UITheme.RADIUS_MD)
	confirm_btn.add_theme_stylebox_override("normal", r_sb)
	confirm_btn.add_theme_stylebox_override("pressed", r_sb)
	hb.add_child(confirm_btn)
	
	cancel_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		_reset_confirm.hide()
	)
	
	confirm_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_ERROR)
		SettingsManager.reset_all_progress()
		_reset_confirm.hide()
	)  

func _build_about_modal() -> void:
	_about_panel = ColorRect.new()
	_about_panel.color = Color(UITheme.BG, 0.95)
	_about_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_about_panel.hide()
	add_child(_about_panel)
	
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_about_panel.add_child(root_vbox)
	
	# HEADER
	var hdr_m = MarginContainer.new()
	hdr_m.add_theme_constant_override("margin_left", 20)
	hdr_m.add_theme_constant_override("margin_right", 20)
	hdr_m.add_theme_constant_override("margin_top", 20)
	hdr_m.add_theme_constant_override("margin_bottom", 20)
	root_vbox.add_child(hdr_m)
	
	var header = UITheme.make_header("ABOUT BOUNZO", true, false, func():
		AudioManager.play(AudioManager.SND_BUTTON)
		_about_panel.hide()
	)
	hdr_m.add_child(header)
	
	# SCROLL AREA
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)
	
	var content_m = MarginContainer.new()
	content_m.add_theme_constant_override("margin_left", 24)
	content_m.add_theme_constant_override("margin_right", 24)
	content_m.add_theme_constant_override("margin_top", 20)
	content_m.add_theme_constant_override("margin_bottom", 40)
	content_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_m)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "AboutContentVBox"
	content_vbox.add_theme_constant_override("separation", 24)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_m.add_child(content_vbox)
	
	# LOGO
	var logo_vb = VBoxContainer.new()
	logo_vb.add_theme_constant_override("separation", 8)
	content_vbox.add_child(logo_vb)
	
	var logo_tex = TextureRect.new()
	logo_tex.texture = load("res://bounzo_logo.png")
	logo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_tex.custom_minimum_size = Vector2(180, 180)
	logo_vb.add_child(logo_tex)
	
	# ABOUT THE GAME
	var about_card = _make_section_card("ABOUT THE GAME")
	content_vbox.add_child(about_card)
	var about_lbl = Label.new()
	about_lbl.text = "BOUNZO is a fast-paced neon arcade game built around precision, timing and the constant challenge to beat your best run."
	about_lbl.label_settings = UITheme.ls(16, Color(0.8, 0.8, 0.8))
	about_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about_card.get_node("Margin/VBox").add_child(about_lbl)
	
	# DEVELOPED BY
	var dev_card = _make_section_card("DEVELOPED BY")
	content_vbox.add_child(dev_card)
	var dev_vb = dev_card.get_node("Margin/VBox")
	var dev_name = Label.new()
	dev_name.text = "AYZUS"
	dev_name.label_settings = UITheme.ls_glow_title(28, Color("#FFD700"), Color("#FFD700", 0.6))
	dev_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_vb.add_child(dev_name)
	var dev_sub = Label.new()
	dev_sub.text = "AYMANINFOTECH"
	dev_sub.label_settings = UITheme.ls(14, UITheme.MUTED)
	dev_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_vb.add_child(dev_sub)
	
	
	# TECHNOLOGY
	var tech_card = _make_section_card("TECHNOLOGY")
	content_vbox.add_child(tech_card)
	var tech_vb = tech_card.get_node("Margin/VBox")
	var tech_title = Label.new()
	tech_title.text = "POWERED BY GODOT"
	tech_title.label_settings = UITheme.ls(18, UITheme.CYAN)
	tech_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tech_vb.add_child(tech_title)
	var tech_desc = Label.new()
	tech_desc.text = "Engine: Godot Engine\nGraphics: Procedural neon rendering"
	tech_desc.label_settings = UITheme.ls(16, Color(0.8, 0.8, 0.8))
	tech_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tech_vb.add_child(tech_desc)
	
	# MUSIC & SOUND
	var music_card = _make_section_card("MUSIC & SOUND")
	content_vbox.add_child(music_card)
	var music_vb = music_card.get_node("Margin/VBox")
	
	var make_credit_group = func(title_text: String, items: Array):
		var group = VBoxContainer.new()
		var lbl = Label.new()
		lbl.text = title_text
		lbl.label_settings = UITheme.ls(14, UITheme.MAGENTA)
		group.add_child(lbl)
		for item in items:
			var i_lbl = Label.new()
			i_lbl.text = item
			i_lbl.label_settings = UITheme.ls(16, Color(0.9, 0.9, 0.9))
			group.add_child(i_lbl)
		return group
		
	music_vb.add_child(make_credit_group.call("🎵 MUSIC", ["Royalty-Free / Licensed Music", "Source: YouTube – No Copyright Music"]))
	var sp3 = Control.new(); sp3.custom_minimum_size = Vector2(0, 10); music_vb.add_child(sp3)
	music_vb.add_child(make_credit_group.call("🔊 SOUND EFFECTS", ["Procedurally Generated"]))
	
	# FOOTER
	var footer_vb = VBoxContainer.new()
	footer_vb.add_theme_constant_override("separation", 8)
	content_vbox.add_child(footer_vb)
	
	var f_lines = [
		["BOUNZO", UITheme.CYAN, 18],
		["Version 1.0.0", UITheme.MUTED, 14],
		["Developed by AYZUS", Color(0.8, 0.8, 0.8), 14],
		["© 2026 AYZUS", Color(0.6, 0.6, 0.6), 12],
		["All rights reserved.", Color(0.6, 0.6, 0.6), 12]
	]
	
	for line in f_lines:
		var lbl = Label.new()
		lbl.text = line[0]
		lbl.label_settings = UITheme.ls(line[2], line[1])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer_vb.add_child(lbl)

func _on_reset_clicked() -> void:
	_reset_confirm.show()  

func _on_about_clicked() -> void:
	_about_panel.show()
	_about_panel.modulate = Color(1, 1, 1, 0)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_about_panel, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_SINE)
	
	var cards_container = _about_panel.find_child("AboutContentVBox", true, false)
	if cards_container:
		var delay = 0.0
		for child in cards_container.get_children():
			child.modulate = Color(1, 1, 1, 0)
			tw.tween_property(child, "modulate", Color.WHITE, 0.3).set_delay(delay)
			delay += 0.05   
func _on_how_to_play_clicked() -> void:
	AudioManager.play(AudioManager.SND_BUTTON)
	hide()
	var ui = get_parent()
	if ui and ui.get_parent():
		var game = ui.get_parent()
		if "tutorial_manager" in game and game.tutorial_manager:
			if ui.has_node("PausePanel"):
				ui.get_node("PausePanel").hide()
			if ui.has_node("MainMenuPanel"):
				ui.get_node("MainMenuPanel").hide()
			if ui.has_node("HUD"):
				ui.get_node("HUD").hide()
			game._state = 1 # State.PLAYING
			game.get_tree().paused = false
			game.tutorial_manager.start_tutorial()
