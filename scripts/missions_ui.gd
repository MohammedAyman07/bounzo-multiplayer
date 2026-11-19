extends Control

# =====================================================
# MISSIONS UI — Premium Redesign
# =====================================================

var _cards_vbox: VBoxContainer

func _ready() -> void:
	name = "MissionsPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport_rect().size)
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(UITheme.BG, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root VBox
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# ── HEADER ──────────────────────────────────────────
	var hdr_m = MarginContainer.new()
	hdr_m.add_theme_constant_override("margin_left",  20)
	hdr_m.add_theme_constant_override("margin_right", 20)
	hdr_m.add_theme_constant_override("margin_top",   20)
	hdr_m.add_theme_constant_override("margin_bottom", 20)
	root_vbox.add_child(hdr_m)

	var header = UITheme.make_header("MISSIONS", true, true, func():
		hide()
		var ui = get_parent()
		if ui and ui.has_node("MainMenuPanel"):
			ui.get_node("MainMenuPanel").show()
	)
	hdr_m.add_child(header)

	var coins_cap = header.get_node_or_null("HeaderCoinCap")
	if coins_cap:
		var lbl = coins_cap.find_child("CoinLabel", true, false)
		if lbl: lbl.text = str(CurrencyManager.get_coins())
		CurrencyManager.coins_changed.connect(func(amt: int):
			var l = coins_cap.find_child("CoinLabel", true, false)
			if l: l.text = str(amt)
		)
		
	# TODAY BADGE
	var badge_m = MarginContainer.new()
	badge_m.add_theme_constant_override("margin_left", 24)
	badge_m.add_theme_constant_override("margin_bottom", 12)
	root_vbox.add_child(badge_m)
	
	var badge = PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var badge_sb = StyleBoxFlat.new()
	badge_sb.bg_color = UITheme.CYAN.darkened(0.6)
	badge_sb.border_color = UITheme.CYAN
	badge_sb.set_border_width_all(1)
	badge_sb.set_corner_radius_all(12)
	badge_sb.content_margin_left = 16
	badge_sb.content_margin_right = 16
	badge_sb.content_margin_top = 4
	badge_sb.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_sb)
	badge_m.add_child(badge)
	
	var badge_lbl = Label.new()
	badge_lbl.text = "TODAY"
	badge_lbl.label_settings = UITheme.ls(12, UITheme.CYAN)
	badge.add_child(badge_lbl)

	# ── SCROLL AREA ─────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var outer_m = MarginContainer.new()
	outer_m.add_theme_constant_override("margin_left",  20)
	outer_m.add_theme_constant_override("margin_right", 20)
	outer_m.add_theme_constant_override("margin_top",   4)
	outer_m.add_theme_constant_override("margin_bottom",20)
	outer_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer_m)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.add_theme_constant_override("separation", 20)
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_m.add_child(_cards_vbox)

	MissionManager.progress_updated.connect(_refresh_ui)
	_refresh_ui()


func _refresh_ui() -> void:
	if not _cards_vbox: return
	for child in _cards_vbox.get_children():
		_cards_vbox.remove_child(child)
		child.queue_free()

	if MissionManager.current_missions.is_empty():
		var lbl = Label.new()
		lbl.text = "No missions available. Check back tomorrow!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.label_settings = UITheme.ls(18, UITheme.MUTED)
		_cards_vbox.add_child(lbl)
		return

	for i in range(MissionManager.current_missions.size()):
		_cards_vbox.add_child(_build_mission_card(MissionManager.current_missions[i], i))


func _build_mission_card(m: Dictionary, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_sb = UITheme.glass_panel(UITheme.RADIUS_LG)
	if m["claimed"]:
		card_sb = UITheme.glass_panel_accent(UITheme.SUCCESS, UITheme.RADIUS_LG)
	elif m["completed"]:
		card_sb = UITheme.glass_panel_accent(UITheme.CYAN, UITheme.RADIUS_LG)
	card.add_theme_stylebox_override("panel", card_sb)

	var outer_m = MarginContainer.new()
	outer_m.add_theme_constant_override("margin_left",  UITheme.SP_LG)
	outer_m.add_theme_constant_override("margin_right", UITheme.SP_LG)
	outer_m.add_theme_constant_override("margin_top",   UITheme.SP_MD)
	outer_m.add_theme_constant_override("margin_bottom",UITheme.SP_MD)
	card.add_child(outer_m)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	outer_m.add_child(hbox)
	
	# Icon (left side)
	var icon_cont = CenterContainer.new()
	icon_cont.custom_minimum_size = Vector2(40, 40)
	icon_cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var m_icon = UIIcon.new(UIIcon.Type.MISSIONS, UITheme.CYAN, 32)
	icon_cont.add_child(m_icon)
	hbox.add_child(icon_cont)

	# Main content VBox
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(vbox)

	# Top row (Title + Coin)
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(top_hbox)

	var desc_lbl = Label.new()
	desc_lbl.text = m["data"]["desc"].to_upper()
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.label_settings = UITheme.ls_title_font(16, UITheme.WHITE)
	top_hbox.add_child(desc_lbl)

	var rew_hc = HBoxContainer.new()
	rew_hc.add_theme_constant_override("separation", 4)
	top_hbox.add_child(rew_hc)
	rew_hc.add_child(UIIcon.new(UIIcon.Type.COIN, UITheme.GOLD, 18))
	var rew_lbl = Label.new()
	rew_lbl.text = str(m["data"]["reward"])
	rew_lbl.label_settings = UITheme.ls_title_font(16, UITheme.GOLD)
	rew_hc.add_child(rew_lbl)

	# Progress label
	var prog_lbl = Label.new()
	prog_lbl.text = "%d / %d" % [m["progress"], m["data"]["target"]]
	prog_lbl.label_settings = UITheme.ls(14, UITheme.MUTED)
	vbox.add_child(prog_lbl)

	# Bottom row (Progress bar + Claim button)
	var bot_hbox = HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(bot_hbox)

	# Progress bar track
	var track = PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 10)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track_sb = StyleBoxFlat.new()
	track_sb.bg_color = UITheme.SURFACE_LT
	track_sb.set_corner_radius_all(5)
	track.add_theme_stylebox_override("panel", track_sb)
	bot_hbox.add_child(track)

	# Progress fill
	var fill_ratio = clampf(float(m["progress"]) / float(max(m["data"]["target"], 1)), 0.0, 1.0)
	if fill_ratio > 0.0:
		var fill = PanelContainer.new()
		fill.anchor_left   = 0.0
		fill.anchor_top    = 0.0
		fill.anchor_right  = fill_ratio
		fill.anchor_bottom = 1.0
		fill.offset_right  = 0
		var fill_sb = StyleBoxFlat.new()
		fill_sb.bg_color = UITheme.SUCCESS if m["completed"] else UITheme.PURPLE
		fill_sb.set_corner_radius_all(5)
		fill.add_theme_stylebox_override("panel", fill_sb)
		track.add_child(fill)

	# Action
	if m["claimed"]:
		var claimed_lbl = Label.new()
		claimed_lbl.text = "CLAIMED"
		claimed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		claimed_lbl.label_settings = UITheme.ls_title_font(14, UITheme.SUCCESS)
		bot_hbox.add_child(claimed_lbl)
	elif m["completed"]:
		var claim_btn = Button.new()
		claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
		claim_btn.add_theme_stylebox_override("normal",  UITheme.btn_primary(UITheme.RADIUS_SM))
		claim_btn.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed(UITheme.RADIUS_SM))
		var claim_center = CenterContainer.new()
		claim_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		claim_btn.add_child(claim_center)
		var claim_lbl = Label.new()
		claim_lbl.text = "CLAIM"
		claim_lbl.label_settings = UITheme.ls_title_font(14, UITheme.BLACK)
		claim_center.add_child(claim_lbl)
		claim_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_REWARD)
			MissionManager.claim_reward(index)
		)
		bot_hbox.add_child(claim_btn)

		var watch_ad_btn = Button.new()
		watch_ad_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		watch_ad_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
		watch_ad_btn.add_theme_stylebox_override("normal",  UITheme.btn_secondary(UITheme.GOLD))
		watch_ad_btn.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed(UITheme.RADIUS_SM))
		var wa_center = CenterContainer.new()
		wa_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		watch_ad_btn.add_child(wa_center)
		var wa_hc = HBoxContainer.new()
		wa_hc.add_theme_constant_override("separation", 8)
		wa_center.add_child(wa_hc)
		var wa_icon = UIIcon.new(UIIcon.Type.PLAY, UITheme.GOLD, 16)
		wa_hc.add_child(wa_icon)
		var wa_lbl = Label.new()
		wa_lbl.text = "AD (2X)"
		wa_lbl.label_settings = UITheme.ls_title_font(14, UITheme.GOLD)
		wa_hc.add_child(wa_lbl)
		watch_ad_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			AdManager.show_rewarded("mission_2x_" + str(index))
		)
		bot_hbox.add_child(watch_ad_btn)

	return card
