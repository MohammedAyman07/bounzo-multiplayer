extends CanvasLayer

var _chal_btn_ref: Button
var _chal_icon_hb: Control
var _chal_rank_lbl: Label
var _chal_progress_lbl: Label
var _chal_next_pill: Control
var _challenges_scale_tween: Tween
var _challenges_glow_tween: Tween

# =====================================================
# UI BUILDER — Premium Redesign
# =====================================================

func _ready() -> void:
	layer = 10
	_build_main_menu()
	_restyle_hud()
	_restyle_game_over()
	_restyle_pause()
	_build_shop()
	_build_daily()
	_build_missions()
	_build_settings()
	_build_challenges()
	_build_free_coins_panel()
	refresh_free_coins_ui()

	CurrencyManager.coins_changed.connect(_on_global_coins_changed)

func _on_global_coins_changed(amt: int) -> void:
	# Update HUD coin capsule
	var hud_cap = $HUD.get_node_or_null("HUDCoinCap")
	if hud_cap:
		var lbl = hud_cap.find_child("CoinLabel", true, false)
		if lbl:
			lbl.text = str(amt)
			
	# Update MainMenu coin capsule
	var menu = get_node_or_null("MainMenuPanel")
	if is_instance_valid(menu):
		var menu_cap = menu.find_child("MenuCoinCap", true, false)
		if is_instance_valid(menu_cap):
			var lbl = menu_cap.find_child("CoinLabel", true, false)
			if lbl:
				lbl.text = str(amt)
				
	# Also update any visible header coin capsule (shop/daily/missions panels)
	for panel in [$"ShopPanel", $"DailyPanel", $"MissionsPanel"]:
		if is_instance_valid(panel) and panel.visible:
			var cap = panel.find_child("HeaderCoinCap", true, false)
			if cap:
				var lbl2 = cap.find_child("CoinLabel", true, false)
				if lbl2:
					lbl2.text = str(amt)

# =====================================================
# TRANSITION LOGIC
# =====================================================

func _transition_to(from: Control, to: Control) -> void:
	from.hide()
	to.show()
	
	if to.name in ["ShopPanel", "DailyPanel", "MissionsPanel", "SettingsPanel"]:
		AdManager.show_banner()
	else:
		AdManager.hide_banner()

# =====================================================
# MAIN MENU
# =====================================================

func _build_main_menu() -> void:
	var menu = Control.new()
	menu.name = "MainMenuPanel"
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.visibility_changed.connect(func():
		if menu.visible:
			_refresh_challenges_card_data()
	)
	
	# Dark overlay for depth
	var overlay = ColorRect.new()
	overlay.color = Color(UITheme.BG, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(overlay)

	# --- NEW SAFE AREA CONTAINER ---
	var safe_margin = MarginContainer.new()
	safe_margin.set_script(load("res://scripts/safe_area_margin.gd"))
	safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(safe_margin)
	
	var safe_content = Control.new()
	safe_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_child(safe_content)

	# ── TOP BAR ──────────────────────────────────────────
	var top_margin = MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.offset_bottom = 80.0
	top_margin.add_theme_constant_override("margin_left", UITheme.SP_LG)
	top_margin.add_theme_constant_override("margin_right", UITheme.SP_LG)
	top_margin.add_theme_constant_override("margin_top", UITheme.SP_LG)
	safe_content.add_child(top_margin)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", UITheme.SP_SM)
	top_margin.add_child(top_hbox)

	var coin_cap = UITheme.make_coin_capsule(CurrencyManager.get_coins(), true, func():
		AudioManager.play(AudioManager.SND_BUTTON)
		var fcp = get_node_or_null("FreeCoinsPanel")
		if fcp: fcp.show()
	)
	coin_cap.name = "MenuCoinCap"
	top_hbox.add_child(coin_cap)


	var spacer_top = Control.new()
	spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer_top)
	
	# Removed Settings Icon Button from top right as it is now in the main grid

	var mid_vbox = VBoxContainer.new()
	mid_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	mid_vbox.offset_top = 80.0
	mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_vbox.add_theme_constant_override("separation", UITheme.SP_MD)
	safe_content.add_child(mid_vbox)

	var logo_tex = TextureRect.new()
	logo_tex.texture = load("res://bounzo_logo.png")
	logo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_tex.set_script(load("res://scripts/responsive_logo.gd"))
	mid_vbox.add_child(logo_tex)
	
	var spacer1 = Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_vbox.add_child(spacer1)

	# ── PLAY BUTTON ───────────────────────────────────────
	var play_hbox = HBoxContainer.new()
	play_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_vbox.add_child(play_hbox)
	
	var play_btn = Button.new()
	play_btn.name = "PlayBtn"
	play_btn.custom_minimum_size = Vector2(280, UITheme.BTN_H_LG)
	play_btn.add_theme_stylebox_override("normal", UITheme.btn_primary())
	play_btn.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed())
	play_btn.add_theme_stylebox_override("hover", UITheme.btn_primary())
	
	var play_center = CenterContainer.new()
	play_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_btn.add_child(play_center)
	var play_content = HBoxContainer.new()
	play_content.add_theme_constant_override("separation", 12)
	play_center.add_child(play_content)
	
	var play_icon = UIIcon.new(UIIcon.Type.PLAY, UITheme.BLACK, 28)
	play_content.add_child(play_icon)
	var play_lbl = Label.new()
	play_lbl.text = "PLAY"
	play_lbl.label_settings = UITheme.ls_button(UITheme.BLACK)
	play_content.add_child(play_lbl)
	
	play_btn.pivot_offset = play_btn.custom_minimum_size / 2.0
	play_btn.button_down.connect(func():
		var t = play_btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(play_btn, "scale", Vector2(0.97, 0.97), 0.1)
	)
	play_btn.button_up.connect(func():
		var t = play_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.2)
	)
	
	play_hbox.add_child(play_btn)

	# ── MULTIPLAYER BUTTON (DEDICATED ONLINE MODE) ────────
	var multi_hbox = HBoxContainer.new()
	multi_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_vbox.add_child(multi_hbox)

	var multi_btn = Button.new()
	multi_btn.name = "MultiplayerBtn"
	multi_btn.custom_minimum_size = Vector2(280, 56)

	var multi_normal = StyleBoxFlat.new()
	multi_normal.bg_color = Color(0.04, 0.08, 0.16, 0.92)
	multi_normal.border_color = Color(0.098, 0.851, 1.0, 0.85)
	multi_normal.set_border_width_all(2)
	multi_normal.set_corner_radius_all(UITheme.RADIUS_LG)
	multi_normal.shadow_color = Color(0.098, 0.851, 1.0, 0.35)
	multi_normal.shadow_size = 14
	multi_normal.shadow_offset = Vector2(0, 4)

	var multi_pressed = multi_normal.duplicate()
	multi_pressed.bg_color = Color(0.08, 0.16, 0.28, 0.95)
	multi_pressed.shadow_size = 6
	multi_pressed.shadow_offset = Vector2(0, 2)

	var multi_hover = multi_normal.duplicate()
	multi_hover.bg_color = Color(0.06, 0.12, 0.22, 0.95)
	multi_hover.shadow_color = Color(0.098, 0.851, 1.0, 0.5)
	multi_hover.shadow_size = 18

	multi_btn.add_theme_stylebox_override("normal", multi_normal)
	multi_btn.add_theme_stylebox_override("pressed", multi_pressed)
	multi_btn.add_theme_stylebox_override("hover", multi_hover)

	multi_btn.pivot_offset = multi_btn.custom_minimum_size / 2.0
	multi_btn.button_down.connect(func():
		var t = multi_btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(multi_btn, "scale", Vector2(0.97, 0.97), 0.1)
	)
	multi_btn.button_up.connect(func():
		var t = multi_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(multi_btn, "scale", Vector2(1.0, 1.0), 0.2)
	)

	var multi_center = CenterContainer.new()
	multi_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	multi_btn.add_child(multi_center)

	var multi_content = HBoxContainer.new()
	multi_content.add_theme_constant_override("separation", 12)
	multi_center.add_child(multi_content)

	var multi_icon = UIIcon.new(UIIcon.Type.MULTIPLAYER, UITheme.CYAN, 26)
	multi_content.add_child(multi_icon)

	var multi_lbl = Label.new()
	multi_lbl.text = "MULTIPLAYER"
	multi_lbl.label_settings = UITheme.ls_title_font(18, UITheme.WHITE)
	multi_content.add_child(multi_lbl)

	multi_hbox.add_child(multi_btn)

	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_vbox.add_child(spacer2)

	# ── NAVIGATION GRID (5 CARDS - CHALLENGES UNOBSTRUCTED)
	var grid_margin = MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 60)
	grid_margin.add_theme_constant_override("margin_right", 60)
	mid_vbox.add_child(grid_margin)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.SP_MD)
	grid.add_theme_constant_override("v_separation", UITheme.SP_MD)
	grid_margin.add_child(grid)

	var shop_btn = _make_nav_card("ShopPanel", "SHOP", UIIcon.Type.SHOP, UITheme.CYAN)
	var daily_btn = _make_nav_card("DailyPanel", "DAILY", UIIcon.Type.DAILY, UITheme.MAGENTA)
	var missions_btn = _make_nav_card("MissionsPanel", "MISSIONS", UIIcon.Type.MISSIONS, UITheme.PURPLE)
	var chal_btn = _make_challenges_card()
	var set_btn = _make_nav_card("SettingsPanel", "SETTINGS", UIIcon.Type.SETTINGS, UITheme.MUTED)

	grid.add_child(shop_btn)
	grid.add_child(daily_btn)
	grid.add_child(missions_btn)
	grid.add_child(chal_btn)
	grid.add_child(set_btn)
	
	var spacer3 = Control.new()
	spacer3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_vbox.add_child(spacer3)
	
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, UITheme.SP_LG * 3) # Give plenty of space for banner ad
	mid_vbox.add_child(spacer4)
	
	# WIRING
	shop_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		var pnl = get_node_or_null("ShopPanel")
		if pnl: _transition_to(menu, pnl)
	)
	daily_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		var pnl = get_node_or_null("DailyPanel")
		if pnl: _transition_to(menu, pnl)
	)
	missions_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		var pnl = get_node_or_null("MissionsPanel")
		if pnl: _transition_to(menu, pnl)
	)
	set_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		var pnl = get_node_or_null("SettingsPanel")
		if pnl: _transition_to(menu, pnl)
	)
	multi_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		AdManager.hide_banner()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_lobby.tscn")
	)
	
	# Wait, chal_btn is a Control wrapper! The actual button is inside it.
	var chal_actual_btn = chal_btn.get_node("ChallengesBtn")
	if chal_actual_btn:
		chal_actual_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			var pnl = get_node_or_null("ChallengesPanel")
			if pnl: _transition_to(menu, pnl)
		)

	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_child(menu)
	
func _make_nav_card(panel_name: String, title: String, icon_type: int, color: Color) -> Button:
	var btn = Button.new()
	btn.name = title + "Btn"
	btn.custom_minimum_size = Vector2(120, 100)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("normal", UITheme.glass_panel_accent(color, UITheme.RADIUS_MD))
	btn.add_theme_stylebox_override("pressed", UITheme.glass_panel(UITheme.RADIUS_MD))
	btn.add_theme_stylebox_override("hover", UITheme.glass_panel_accent(color.lightened(0.2), UITheme.RADIUS_MD))
	
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.button_down.connect(func():
		var t = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.1)
	)
	btn.button_up.connect(func():
		var t = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	)
	
	var center_c = CenterContainer.new()
	center_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(center_c)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	center_c.add_child(vb)
	
	var icon = UIIcon.new(icon_type, color, 32)
	vb.add_child(icon)
	
	var lbl = Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.label_settings = UITheme.ls(14, UITheme.WHITE)
	vb.add_child(lbl)
	
	return btn

func _make_challenges_card() -> Control:
	var wrapper = Control.new()
	wrapper.name = "ChallengesWrapper"
	wrapper.custom_minimum_size = Vector2(120, 100)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn = Button.new()
	btn.name = "ChallengesBtn"
	
	btn.add_theme_stylebox_override("normal", UITheme.glass_panel_challenges(UITheme.RADIUS_MD))
	btn.add_theme_stylebox_override("pressed", UITheme.glass_panel_challenges(UITheme.RADIUS_MD))
	btn.add_theme_stylebox_override("hover", UITheme.glass_panel_challenges_hover(UITheme.RADIUS_MD))
	
	wrapper.add_child(btn)
	
	# Make it exactly match column width (like Daily), and stretch down to bottom of Settings (100 + 32 + 100 = 232)
	btn.set_anchors_preset(Control.PRESET_TOP_WIDE)
	btn.offset_bottom = 232
	
	btn.pivot_offset = Vector2(wrapper.size.x / 2.0, 232 / 2.0)
	btn.resized.connect(func():
		btn.pivot_offset = Vector2(btn.size.x / 2.0, btn.size.y / 2.0)
	)
	
	btn.button_down.connect(func():
		var t = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1) # Stronger response
	)
	btn.button_up.connect(func():
		var t = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(margin)
	
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)
	
	# Icon - Procedural Target + Trophy combo
	var icon_hb = HBoxContainer.new()
	icon_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(icon_hb)
	_chal_icon_hb = icon_hb
	var rank_emblem = UITheme.make_rank_emblem(ChallengeManager.get_current_rank(), 128)
	icon_hb.add_child(rank_emblem)
	
	var lbl = Label.new()
	lbl.text = "CHALLENGES"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.label_settings = UITheme.ls_title_font(14, UITheme.WHITE)
	vb.add_child(lbl)
	
	_chal_rank_lbl = Label.new()
	_chal_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chal_rank_lbl.label_settings = UITheme.ls_title_font(12, UITheme.WHITE)
	vb.add_child(_chal_rank_lbl)
	
	_chal_progress_lbl = Label.new()
	_chal_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chal_progress_lbl.label_settings = UITheme.ls_title_font(14, UITheme.WHITE)
	vb.add_child(_chal_progress_lbl)
	
	# UP NEXT PILL
	_chal_next_pill = PanelContainer.new()
	var pill_sb = StyleBoxFlat.new()
	pill_sb.bg_color = Color(1.0, 0.0, 1.0, 0.8)
	pill_sb.set_corner_radius_all(10)
	pill_sb.content_margin_left = 6; pill_sb.content_margin_right = 6
	pill_sb.content_margin_top = 2; pill_sb.content_margin_bottom = 2
	_chal_next_pill.add_theme_stylebox_override("panel", pill_sb)
	_chal_next_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chal_next_pill.offset_top = -10
	_chal_next_pill.offset_bottom = 10
	
	var next_lbl = Label.new()
	next_lbl.text = "NEXT"
	next_lbl.label_settings = UITheme.ls(10, UITheme.WHITE)
	_chal_next_pill.add_child(next_lbl)
	btn.add_child(_chal_next_pill)
	
	_chal_btn_ref = btn
	_refresh_challenges_card_data()
	_start_challenges_animations()
	
	btn.tree_exiting.connect(func():
		_stop_challenges_animations()
	)
	
	return wrapper

func _refresh_challenges_card_data() -> void:
	if not is_instance_valid(_chal_btn_ref): return
	var current_rank = ChallengeManager.get_current_rank()
	var max_stars = current_rank.required_stars
	var current_stars = ChallengeManager.get_stars_in_rank(current_rank.id)
	
	if is_instance_valid(_chal_btn_ref):
		_chal_btn_ref.add_theme_stylebox_override("normal", UITheme.glass_panel_challenges(current_rank.color, UITheme.RADIUS_MD))
		_chal_btn_ref.add_theme_stylebox_override("pressed", UITheme.glass_panel_challenges(current_rank.color, UITheme.RADIUS_MD))
		_chal_btn_ref.add_theme_stylebox_override("hover", UITheme.glass_panel_challenges_hover(current_rank.color, UITheme.RADIUS_MD))
	
	if is_instance_valid(_chal_icon_hb):
		for child in _chal_icon_hb.get_children():
			child.queue_free()
		var rank_emblem = UITheme.make_rank_emblem(current_rank, 128)
		_chal_icon_hb.add_child(rank_emblem)
	
	if is_instance_valid(_chal_rank_lbl):
		_chal_rank_lbl.text = current_rank.name
		_chal_rank_lbl.label_settings.font_color = current_rank.color
		
	if is_instance_valid(_chal_progress_lbl):
		_chal_progress_lbl.text = "%d / %d" % [current_stars, max_stars]
	
	var has_unfinished = current_stars < max_stars
	_chal_next_pill.visible = has_unfinished

func _start_challenges_animations() -> void:
	if not is_instance_valid(_chal_btn_ref): return
	_stop_challenges_animations()
	
	# Initial Attention Pulse (after 1s)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(_chal_btn_ref):
			if is_instance_valid(_challenges_scale_tween): _challenges_scale_tween.kill()
			_challenges_scale_tween = _chal_btn_ref.create_tween()
			_challenges_scale_tween.tween_property(_chal_btn_ref, "scale", Vector2(1.02, 1.02), 0.15).set_trans(Tween.TRANS_SINE)
			_challenges_scale_tween.tween_property(_chal_btn_ref, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
	)
	
	# Continuous Soft Glow
	_challenges_glow_tween = _chal_btn_ref.create_tween().set_loops()
	_challenges_glow_tween.tween_property(_chal_btn_ref, "self_modulate", Color(1.15, 1.15, 1.15, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	_challenges_glow_tween.tween_property(_chal_btn_ref, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func _stop_challenges_animations() -> void:
	if is_instance_valid(_challenges_glow_tween): _challenges_glow_tween.kill()
	if is_instance_valid(_challenges_scale_tween): _challenges_scale_tween.kill()


# =====================================================
# HUD
# =====================================================

func _restyle_hud() -> void:
	var hud = $HUD
	
	var score_cont = hud.get_node("ScoreContainer")
	score_cont.offset_top = 100; score_cont.offset_bottom = 200
	score_cont.add_theme_constant_override("separation", 2)
	var st = score_cont.get_node("ScoreTitle")
	st.label_settings = UITheme.ls(20, UITheme.MUTED)
	var sl = score_cont.get_node("ScoreLabel")
	sl.label_settings = UITheme.ls_number(64)
	
	var cl = score_cont.get_node_or_null("ChainLabel")
	if not cl:
		cl = Label.new()
		cl.name = "ChainLabel"
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_cont.add_child(cl)
	cl.label_settings = UITheme.ls(24, UITheme.CYAN)
	
	var ml = score_cont.get_node_or_null("MultiplierLabel")
	if not ml:
		ml = Label.new()
		ml.name = "MultiplierLabel"
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_cont.add_child(ml)
	ml.label_settings = UITheme.ls_glow(32, UITheme.YELLOW, UITheme.GOLD)
	
	var pause_btn = hud.get_node("PauseBtn")
	# Force square icon button — no content margins
	var pause_sb = StyleBoxFlat.new()
	pause_sb.bg_color = Color(UITheme.SURFACE, 0.85)
	pause_sb.border_color = Color(UITheme.WHITE, 0.15)
	pause_sb.set_border_width_all(1)
	pause_sb.set_corner_radius_all(12)
	pause_btn.add_theme_stylebox_override("normal", pause_sb)
	var pause_hover_sb = StyleBoxFlat.new()
	pause_hover_sb.bg_color = Color(UITheme.CYAN, 0.25)
	pause_hover_sb.border_color = UITheme.CYAN
	pause_hover_sb.set_border_width_all(1)
	pause_hover_sb.set_corner_radius_all(12)
	pause_btn.add_theme_stylebox_override("hover", pause_hover_sb)
	pause_btn.text = ""
	var picon = UIIcon.new(UIIcon.Type.PAUSE, UITheme.WHITE, 18)
	var p_center = CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_btn.add_child(p_center)
	p_center.add_child(picon)

	# ── COIN CAPSULE (top-left) ──────────────────────────
	var old_coin_hud = hud.get_node_or_null("HUDCoinCap")
	if old_coin_hud: old_coin_hud.queue_free()

	var coin_cap = PanelContainer.new()
	coin_cap.name = "HUDCoinCap"
	coin_cap.layout_mode = 1
	coin_cap.anchor_left   = 0.0; coin_cap.anchor_right  = 0.0
	coin_cap.anchor_top    = 0.0; coin_cap.anchor_bottom = 0.0
	coin_cap.offset_left   = 20; coin_cap.offset_right  = 104
	coin_cap.offset_top    = 48; coin_cap.offset_bottom = 80
	
	pause_btn.anchor_left   = 1.0; pause_btn.anchor_right  = 1.0
	pause_btn.anchor_top    = 0.0; pause_btn.anchor_bottom = 0.0
	pause_btn.offset_left   = -64; pause_btn.offset_right  = -20
	pause_btn.offset_top    = 48;  pause_btn.offset_bottom = 92

	var cap_sb = StyleBoxFlat.new()
	cap_sb.bg_color = Color(0.04, 0.01, 0.12, 0.85)
	cap_sb.border_color = Color(UITheme.GOLD, 0.5)
	cap_sb.set_border_width_all(1)
	cap_sb.set_corner_radius_all(20)
	cap_sb.shadow_color = Color(UITheme.GOLD, 0.2)
	cap_sb.shadow_size = 6
	coin_cap.add_theme_stylebox_override("panel", cap_sb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	coin_cap.add_child(margin)

	var hc = HBoxContainer.new()
	hc.add_theme_constant_override("separation", 5)
	margin.add_child(hc)

	hc.add_child(UIIcon.new(UIIcon.Type.COIN, UITheme.GOLD, 16))

	var coin_lbl = Label.new()
	coin_lbl.name = "CoinLabel"
	coin_lbl.text = str(CurrencyManager.get_coins())
	coin_lbl.label_settings = UITheme.ls_glow_title(16, UITheme.GOLD, Color(UITheme.GOLD, 0.5))
	hc.add_child(coin_lbl)

	hud.add_child(coin_cap)


# =====================================================
# PAUSE
# =====================================================

func _restyle_pause() -> void:
	var p = $PausePanel
	# Deep dark backdrop — gameplay visible but clearly subordinate
	p.color = Color(0.01, 0.0, 0.05, 0.88)

	var vbox = p.get_node("VBox")
	
	# Remove any old injected panel from previous runs
	var old_panel = p.get_node_or_null("PauseCard")
	if old_panel: old_panel.queue_free()
	
	# ── GLASS CARD ──────────────────────────────────────
	var card = Panel.new()
	card.name = "PauseCard"
	# Size and center via anchors
	card.anchor_left   = 0.5; card.anchor_right  = 0.5
	card.anchor_top    = 0.5; card.anchor_bottom = 0.5
	card.offset_left   = -160; card.offset_right  = 160
	card.offset_top    = -220; card.offset_bottom = 220
	
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.04, 0.01, 0.10, 0.95)
	card_sb.border_color = Color(UITheme.CYAN, 0.35)
	card_sb.border_width_top = 1
	card_sb.border_width_left = 1
	card_sb.border_width_right = 1
	card_sb.border_width_bottom = 1
	card_sb.set_corner_radius_all(UITheme.RADIUS_XL)
	card_sb.shadow_color = Color(UITheme.CYAN, 0.15)
	card_sb.shadow_size = 24
	card.add_theme_stylebox_override("panel", card_sb)
	p.add_child(card)
	p.move_child(card, 0)

	# ── POSITION THE VBOX TO MATCH CARD ─────────────────
	vbox.anchor_left   = 0.5; vbox.anchor_right  = 0.5
	vbox.anchor_top    = 0.5; vbox.anchor_bottom = 0.5
	vbox.offset_left   = -140; vbox.offset_right  = 140
	vbox.offset_top    = -200; vbox.offset_bottom = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)

	# ── DECORATIVE TOP ACCENT LINE ───────────────────────
	# (reuse first spacer slot if it exists)

	# ── PAUSED TITLE ────────────────────────────────────
	var paused_title = p.get_node("VBox/PausedTitle")
	var pt_ls = LabelSettings.new()
	pt_ls.font_size = 44
	pt_ls.font_color = UITheme.WHITE
	pt_ls.shadow_color = Color(UITheme.CYAN, 0.8)
	pt_ls.shadow_size = 12
	pt_ls.outline_size = 2
	pt_ls.outline_color = Color(UITheme.CYAN, 0.4)
	paused_title.label_settings = pt_ls
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ── DIVIDER ──────────────────────────────────────────
	var div_old = vbox.get_node_or_null("PauseDivider")
	if not div_old:
		var div = PanelContainer.new()
		div.name = "PauseDivider"
		div.custom_minimum_size = Vector2(280, 1)
		var div_sb = StyleBoxFlat.new()
		div_sb.bg_color = Color(UITheme.CYAN, 0.2)
		div.add_theme_stylebox_override("panel", div_sb)
		vbox.add_child(div)
		vbox.move_child(div, 1) # after title

	# ── SPACER (after title) ─────────────────────────────
	var sp_old = vbox.get_node_or_null("Spacer1")
	if sp_old:
		sp_old.custom_minimum_size = Vector2(0, 8)

	# ── RESUME BUTTON ────────────────────────────────────
	var res = p.get_node("VBox/ResumeBtn")
	res.text = ""
	res.custom_minimum_size = Vector2(280, UITheme.BTN_H_MD)
	res.add_theme_stylebox_override("normal", UITheme.btn_primary())
	res.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed())
	# Clear old children if re-run
	for c in res.get_children(): c.queue_free()
	var res_center = CenterContainer.new()
	res_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	res.add_child(res_center)
	var res_hc = HBoxContainer.new()
	res_hc.add_theme_constant_override("separation", 12)
	res_center.add_child(res_hc)
	res_hc.add_child(UIIcon.new(UIIcon.Type.PLAY, UITheme.BLACK, 22))
	var res_lbl = Label.new()
	res_lbl.text = "RESUME"
	res_lbl.label_settings = UITheme.ls_button(UITheme.BLACK)
	res_hc.add_child(res_lbl)

	# ── RESTART BUTTON ───────────────────────────────────
	var rst = p.get_node("VBox/RestartBtn")
	rst.text = ""
	rst.custom_minimum_size = Vector2(280, UITheme.BTN_H_SM)
	var rst_sb = StyleBoxFlat.new()
	rst_sb.bg_color = Color(UITheme.CYAN, 0.1)
	rst_sb.border_color = UITheme.CYAN
	rst_sb.set_border_width_all(2)
	rst_sb.set_corner_radius_all(UITheme.RADIUS_MD)
	rst.add_theme_stylebox_override("normal", rst_sb)
	var rst_hover = StyleBoxFlat.new()
	rst_hover.bg_color = Color(UITheme.CYAN, 0.25)
	rst_hover.border_color = UITheme.CYAN
	rst_hover.set_border_width_all(2)
	rst_hover.set_corner_radius_all(UITheme.RADIUS_MD)
	rst.add_theme_stylebox_override("hover", rst_hover)
	for c in rst.get_children(): c.queue_free()
	var rst_center = CenterContainer.new()
	rst_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	rst.add_child(rst_center)
	var rst_hc = HBoxContainer.new()
	rst_hc.add_theme_constant_override("separation", 10)
	rst_center.add_child(rst_hc)
	rst_hc.add_child(UIIcon.new(UIIcon.Type.RESTART, UITheme.CYAN, 20))
	var rst_lbl = Label.new()
	rst_lbl.text = "RESTART"
	rst_lbl.label_settings = UITheme.ls_title_font(18, UITheme.CYAN)
	rst_hc.add_child(rst_lbl)

	# ── SETTINGS BUTTON ──────────────────────────────────
	var set_btn = p.get_node_or_null("VBox/SettingsBtn")
	if not set_btn:
		set_btn = Button.new()
		set_btn.name = "SettingsBtn"
		p.get_node("VBox").add_child(set_btn)
	set_btn.text = ""
	set_btn.custom_minimum_size = Vector2(280, UITheme.BTN_H_SM)
	var set_sb = StyleBoxFlat.new()
	set_sb.bg_color = Color(UITheme.MUTED, 0.08)
	set_sb.border_color = Color(UITheme.MUTED, 0.3)
	set_sb.set_border_width_all(1)
	set_sb.set_corner_radius_all(UITheme.RADIUS_MD)
	set_btn.add_theme_stylebox_override("normal", set_sb)
	for c in set_btn.get_children(): c.queue_free()
	var set_center = CenterContainer.new()
	set_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	set_btn.add_child(set_center)
	var set_hc = HBoxContainer.new()
	set_hc.add_theme_constant_override("separation", 10)
	set_center.add_child(set_hc)
	set_hc.add_child(UIIcon.new(UIIcon.Type.SETTINGS, UITheme.MUTED, 18))
	var set_lbl = Label.new()
	set_lbl.text = "SETTINGS"
	set_lbl.label_settings = UITheme.ls_title_font(16, UITheme.MUTED)
	set_hc.add_child(set_lbl)
	
	# ── HOME BUTTON ──────────────────────────────────────
	var home_btn = vbox.get_node_or_null("HomeBtn")
	if not home_btn:
		home_btn = Button.new()
		home_btn.name = "HomeBtn"
		vbox.add_child(home_btn)
	home_btn.text = ""
	home_btn.custom_minimum_size = Vector2(280, UITheme.BTN_H_SM)
	var home_sb = StyleBoxFlat.new()
	home_sb.bg_color = Color(UITheme.MUTED, 0.08)
	home_sb.border_color = Color(UITheme.MUTED, 0.3)
	home_sb.set_border_width_all(1)
	home_sb.set_corner_radius_all(UITheme.RADIUS_MD)
	home_btn.add_theme_stylebox_override("normal", home_sb)
	for c in home_btn.get_children(): c.queue_free()
	var home_center = CenterContainer.new()
	home_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	home_btn.add_child(home_center)
	var home_hc = HBoxContainer.new()
	home_hc.add_theme_constant_override("separation", 10)
	home_center.add_child(home_hc)
	home_hc.add_child(UIIcon.new(UIIcon.Type.HOME, UITheme.MUTED, 18))
	var home_lbl = Label.new()
	home_lbl.text = "HOME"
	home_lbl.label_settings = UITheme.ls_title_font(16, UITheme.MUTED)
	home_hc.add_child(home_lbl)


# =====================================================
# GAME OVER
# =====================================================

func _restyle_game_over() -> void:
	var p = $GameOverPanel
	p.color = Color(UITheme.BG, 0.95)

	var vbox = p.get_node("VBox")
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", UITheme.SP_SM)
	
	var go_title = vbox.get_node("GameOverTitle")
	go_title.label_settings = UITheme.ls_glow_logo(48, UITheme.WHITE, UITheme.MAGENTA)
	
	var new_rec = vbox.get_node_or_null("NewRecordLabel")
	if not new_rec:
		new_rec = Label.new()
		new_rec.name = "NewRecordLabel"
		new_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(new_rec)
		vbox.move_child(new_rec, 1)
	new_rec.label_settings = UITheme.ls_title_font(18, UITheme.YELLOW)
	
	var old_sub = vbox.get_node_or_null("ScoreSubLabel")
	if old_sub: old_sub.queue_free()
	var old_val = vbox.get_node_or_null("ScoreValue")
	if old_val: old_val.queue_free()
	
	# Score display
	var score_box = vbox.get_node_or_null("ScoreBox")
	if not score_box:
		score_box = PanelContainer.new()
		score_box.name = "ScoreBox"
		vbox.add_child(score_box)
		vbox.move_child(score_box, 2)
		var s_margin = MarginContainer.new()
		s_margin.name = "Margin"
		score_box.add_child(s_margin)
		var s_vbox = VBoxContainer.new()
		s_vbox.name = "VBox"
		s_margin.add_child(s_vbox)
		var st = Label.new()
		st.name = "ScoreTitle"
		st.text = "SCORE"
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_vbox.add_child(st)
		var sv = Label.new()
		sv.name = "ScoreValue"
		sv.text = "0"
		sv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_vbox.add_child(sv)

	score_box.add_theme_stylebox_override("panel", UITheme.glass_panel_accent(UITheme.MAGENTA, UITheme.RADIUS_MD))
	score_box.custom_minimum_size = Vector2(320, 0)
	var s_vbox_ref = score_box.get_node("Margin/VBox")
	s_vbox_ref.get_node("ScoreTitle").label_settings = UITheme.ls(16, UITheme.MUTED)
	s_vbox_ref.get_node("ScoreValue").label_settings = UITheme.ls_number(64)
	
	# Stats List 
	var stats_grid = vbox.get_node_or_null("StatsGrid")
	if not stats_grid:
		stats_grid = GridContainer.new()
		stats_grid.name = "StatsGrid"
		vbox.add_child(stats_grid)
		vbox.move_child(stats_grid, 3)
		
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
		
	# Clean stat list logic
	stats_grid.columns = 1
	stats_grid.add_theme_constant_override("v_separation", 6)
	
	_add_stat_row(stats_grid, UIIcon.Type.TROPHY, UITheme.YELLOW, "BEST SCORE", "BestScoreValue")
	_add_stat_row(stats_grid, UIIcon.Type.CHAIN, UITheme.CYAN, "CHAIN", "ChainValue")
	_add_stat_row(stats_grid, UIIcon.Type.TROPHY, UITheme.GOLD, "BEST CHAIN", "BestChainValue")
	_add_stat_row(stats_grid, UIIcon.Type.COIN, UITheme.GOLD, "COINS EARNED", "CoinsEarnedValue")
	_add_stat_row(stats_grid, UIIcon.Type.COIN, UITheme.MUTED, "TOTAL COINS", "TotalCoinsValue")
	
	# Try Again
	var ta = p.get_node("VBox/TryAgainBtn")
	ta.text = ""
	ta.custom_minimum_size = Vector2(320, UITheme.BTN_H_MD)
	ta.add_theme_stylebox_override("normal", UITheme.btn_primary())
	ta.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed())
	
	var ta_center = CenterContainer.new()
	ta_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ta.add_child(ta_center)
	var ta_hc = HBoxContainer.new()
	ta_hc.add_theme_constant_override("separation", 12)
	ta_center.add_child(ta_hc)
	ta_hc.add_child(UIIcon.new(UIIcon.Type.PLAY, UITheme.BLACK, 24))
	var ta_lbl = Label.new()
	ta_lbl.text = "TRY AGAIN"
	ta_lbl.label_settings = UITheme.ls_button(UITheme.BLACK)
	ta_hc.add_child(ta_lbl)
	
	# Watch Ad
	var wa = p.get_node_or_null("VBox/WatchAdBtn")
	if not wa:
		wa = Button.new()
		wa.name = "WatchAdBtn"
		p.get_node("VBox").add_child(wa)
	wa.text = ""
	wa.custom_minimum_size = Vector2(320, UITheme.BTN_H_SM)
	wa.add_theme_stylebox_override("normal", UITheme.btn_secondary(UITheme.MAGENTA))
	
	var wa_center = CenterContainer.new()
	wa_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wa.add_child(wa_center)
	var wa_hc = HBoxContainer.new()
	wa_hc.add_theme_constant_override("separation", 12)
	wa_center.add_child(wa_hc)
	wa_hc.add_child(UIIcon.new(UIIcon.Type.PLAY, UITheme.MAGENTA, 18))
	var wa_lbl = Label.new()
	wa_lbl.text = "WATCH AD & CONTINUE"
	wa_lbl.label_settings = UITheme.ls_title_font(16, UITheme.MAGENTA)
	wa_hc.add_child(wa_lbl)
	
	# Home
	var home_btn = p.get_node_or_null("VBox/HomeBtn")
	if not home_btn:
		home_btn = Button.new()
		home_btn.name = "HomeBtn"
		p.get_node("VBox").add_child(home_btn)
	home_btn.text = "MAIN MENU"
	home_btn.custom_minimum_size = Vector2(320, UITheme.BTN_H_SM)
	var h_sb = StyleBoxFlat.new()
	h_sb.bg_color = Color(1,1,1, 0.1)
	h_sb.set_corner_radius_all(UITheme.RADIUS_MD)
	home_btn.add_theme_stylebox_override("normal", h_sb)
	home_btn.add_theme_stylebox_override("pressed", h_sb)


func _add_stat_row(grid: Control, icon_type: int, color: Color, title: String, val_name: String) -> void:
	var hc = HBoxContainer.new()
	hc.custom_minimum_size = Vector2(340, 30)
	grid.add_child(hc)
	
	var icon = UIIcon.new(icon_type, color, 20)
	hc.add_child(icon)
	
	var tlbl = Label.new()
	tlbl.text = title
	tlbl.label_settings = UITheme.ls(16, UITheme.MUTED)
	hc.add_child(tlbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(spacer)
	
	var vlbl = Label.new()
	vlbl.name = val_name
	vlbl.text = "0"
	vlbl.label_settings = UITheme.ls_title_font(20, color)
	hc.add_child(vlbl)


# =====================================================
# DYNAMIC PANELS INSTANTIATION
# =====================================================

func _build_shop() -> void:
	if not ResourceLoader.exists("res://scripts/shop_ui.gd"): return
	var scr = load("res://scripts/shop_ui.gd")
	var shop = scr.new()
	shop.name = "ShopPanel"
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shop)
	shop.hide()

func _build_daily() -> void:
	if not ResourceLoader.exists("res://scripts/daily_ui.gd"): return
	var scr = load("res://scripts/daily_ui.gd")
	var daily = scr.new()
	daily.name = "DailyPanel"
	daily.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(daily)
	daily.hide()

func _build_missions() -> void:
	if not ResourceLoader.exists("res://scripts/missions_ui.gd"): return
	var scr = load("res://scripts/missions_ui.gd")
	var missions = scr.new()
	missions.name = "MissionsPanel"
	missions.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(missions)
	missions.hide()

func _build_settings() -> void:
	if not ResourceLoader.exists("res://scripts/settings_ui.gd"): return
	var scr = load("res://scripts/settings_ui.gd")
	var settings = scr.new()
	settings.name = "SettingsPanel"
	settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(settings)
	settings.hide()

func _build_challenges() -> void:
	if not ResourceLoader.exists("res://scripts/challenges_ui.gd"): return
	var scr = load("res://scripts/challenges_ui.gd")
	var pnl = scr.new()
	pnl.name = "ChallengesPanel"
	pnl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pnl)
	pnl.hide()

func _build_free_coins_panel() -> void:
	var panel = Control.new()
	panel.name = "FreeCoinsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.hide()
	
	var bg = ColorRect.new()
	bg.color = Color(UITheme.BG, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	
	var safe = MarginContainer.new()
	safe.set_script(load("res://scripts/safe_area_margin.gd"))
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(safe)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(vbox)
	
	var header = UITheme.make_header("FREE COINS", true, false, func():
		AudioManager.play(AudioManager.SND_BUTTON)
		panel.hide()
	)
	vbox.add_child(header)
	
	var tiers_vbox = VBoxContainer.new()
	tiers_vbox.name = "TiersVBox"
	tiers_vbox.add_theme_constant_override("separation", 16)
	vbox.add_child(tiers_vbox)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(spacer)
	
	add_child(panel)
	
func refresh_free_coins_ui() -> void:
	var p = get_node_or_null("FreeCoinsPanel")
	if not p: return
	var tvbox = p.find_child("TiersVBox", true, false)
	if not tvbox: return
	
	for c in tvbox.get_children():
		c.queue_free()
		
	var prog = SaveManager.data.get("free_coins_progress", {"50": 0, "100": 0, "200": 0, "500": 0, "1000": 0})
	var today = Time.get_date_string_from_system()
	var claimed = SaveManager.data.get("free_coins_claimed", [])
	if SaveManager.data.get("free_coins_date", "") != today:
		claimed = []
	
	var tiers = [
		{"coins": 50, "ads": 1},
		{"coins": 100, "ads": 2},
		{"coins": 200, "ads": 3},
		{"coins": 500, "ads": 4},
		{"coins": 1000, "ads": 5}
	]
	
	for t in tiers:
		var curr = prog.get(str(t.coins), 0)
		var req = t.ads
		var row = PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.glass_panel_challenges(UITheme.GOLD, 16))
		
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 20)
		m.add_theme_constant_override("margin_right", 20)
		m.add_theme_constant_override("margin_top", 20)
		m.add_theme_constant_override("margin_bottom", 20)
		row.add_child(m)
		
		var hc = HBoxContainer.new()
		hc.add_theme_constant_override("separation", 20)
		m.add_child(hc)
		
		var icon = UIIcon.new(UIIcon.Type.COIN, UITheme.GOLD, 40)
		hc.add_child(icon)
		
		var l_vbox = VBoxContainer.new()
		l_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hc.add_child(l_vbox)
		
		var amt = Label.new()
		amt.text = "%d COINS" % t.coins
		amt.label_settings = UITheme.ls_glow_title(24, UITheme.GOLD, UITheme.GOLD)
		l_vbox.add_child(amt)
		
		var btn = UITheme.make_filled_button("WATCH AD", UITheme.MAGENTA)
		if req > 1:
			btn.text = "WATCH AD\n(%d/%d)" % [curr, req]
			
		btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			AdManager.show_rewarded("free_tier_%d" % t.coins)
		)
			
		hc.add_child(btn)
		tvbox.add_child(row)
