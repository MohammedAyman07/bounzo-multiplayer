extends Control

# =====================================================
# DAILY UI — Premium Redesign
# =====================================================

var _desc_label: Label
var _progress_nums: Label
var _progress_fill: Control
var _reward_label: Label
var _status_label: Label
var _claim_btn: Button
var _watch_ad_btn: Button
var _btns_hbox: HBoxContainer

func _ready() -> void:
	name = "DailyPanel"
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

	var header = UITheme.make_header("DAILY CHALLENGE", true, true, func():
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

	# ── SCROLL AREA ─────────────────────────────────────
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
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_theme_constant_override("separation", 0)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_m.add_child(content_vbox)

	# ── TODAY BADGE ───────────────────────────────────────
	var badge_m = MarginContainer.new()
	badge_m.add_theme_constant_override("margin_bottom", -16)
	content_vbox.add_child(badge_m)
	
	var badge = PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var badge_sb = StyleBoxFlat.new()
	badge_sb.bg_color = UITheme.MAGENTA.darkened(0.6)
	badge_sb.border_color = UITheme.MAGENTA
	badge_sb.set_border_width_all(1)
	badge_sb.set_corner_radius_all(12)
	badge_sb.content_margin_left = 16
	badge_sb.content_margin_right = 16
	badge_sb.content_margin_top = 4
	badge_sb.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_sb)
	badge.z_index = 1
	badge_m.add_child(badge)
	
	var badge_lbl = Label.new()
	badge_lbl.text = "TODAY"
	badge_lbl.label_settings = UITheme.ls(12, UITheme.MAGENTA)
	badge.add_child(badge_lbl)

	# ── CHALLENGE CARD ────────────────────────────────────
	var card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", UITheme.glass_panel(UITheme.RADIUS_XL))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(card)

	var inner_m = MarginContainer.new()
	inner_m.add_theme_constant_override("margin_left",  UITheme.SP_LG)
	inner_m.add_theme_constant_override("margin_right", UITheme.SP_LG)
	inner_m.add_theme_constant_override("margin_top",   40) # Space for badge
	inner_m.add_theme_constant_override("margin_bottom",UITheme.SP_LG)
	card.add_child(inner_m)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_theme_constant_override("separation", 24)
	inner_m.add_child(inner_vbox)

	var today_lbl = Label.new()
	today_lbl.text = "TODAY'S CHALLENGE"
	today_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	today_lbl.label_settings = UITheme.ls(14, UITheme.MUTED)
	inner_vbox.add_child(today_lbl)

	_desc_label = Label.new()
	_desc_label.text = "Loading..."
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.label_settings = UITheme.ls_heading()
	inner_vbox.add_child(_desc_label)

	# ── PROGRESS BAR ─────────────────────────────────────
	# Track container - clip children so fill never overflows
	var track = Control.new()
	track.custom_minimum_size = Vector2(0, 16)
	track.clip_contents = true
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(track)

	# Track background
	var track_bg = PanelContainer.new()
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var track_sb = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.15, 0.05, 0.2)
	track_sb.set_corner_radius_all(8)
	track_sb.shadow_color = Color(0,0,0,0.8)
	track_sb.shadow_size = 4
	track_bg.add_theme_stylebox_override("panel", track_sb)
	track.add_child(track_bg)

	# Fill bar — width controlled via size in _refresh_ui
	_progress_fill = Control.new()
	_progress_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	var fill_draw = PanelContainer.new()
	fill_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = UITheme.CYAN
	fill_sb.set_corner_radius_all(8)
	fill_sb.shadow_color = Color(UITheme.CYAN, 0.5)
	fill_sb.shadow_size = 8
	fill_draw.add_theme_stylebox_override("panel", fill_sb)
	_progress_fill.add_child(fill_draw)
	track.add_child(_progress_fill)

	_progress_nums = Label.new()
	_progress_nums.text = "0 / 0"
	_progress_nums.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_nums.label_settings = UITheme.ls_number(64)
	inner_vbox.add_child(_progress_nums)

	inner_vbox.add_child(_make_divider())

	var rew_title_lbl = Label.new()
	rew_title_lbl.text = "REWARD"
	rew_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rew_title_lbl.label_settings = UITheme.ls(14, UITheme.MUTED)
	inner_vbox.add_child(rew_title_lbl)

	var rew_hbox = HBoxContainer.new()
	rew_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_hbox.add_theme_constant_override("separation", 12)
	inner_vbox.add_child(rew_hbox)
	
	rew_hbox.add_child(UIIcon.new(UIIcon.Type.COIN, UITheme.GOLD, 32))
	
	_reward_label = Label.new()
	_reward_label.text = "+0"
	_reward_label.label_settings = UITheme.ls_glow_title(36, UITheme.GOLD, UITheme.YELLOW)
	rew_hbox.add_child(_reward_label)

	inner_vbox.add_child(_make_divider())

	_status_label = Label.new()
	_status_label.text = "IN PROGRESS"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.label_settings = UITheme.ls(16, UITheme.MUTED)
	inner_vbox.add_child(_status_label)

	_btns_hbox = HBoxContainer.new()
	_btns_hbox.add_theme_constant_override("separation", 12)
	inner_vbox.add_child(_btns_hbox)
	
	_claim_btn = Button.new()
	_claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_claim_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_MD)
	_claim_btn.add_theme_stylebox_override("normal",  UITheme.btn_primary(UITheme.RADIUS_LG))
	_claim_btn.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed())
	
	var claim_center = CenterContainer.new()
	claim_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_claim_btn.add_child(claim_center)
	var claim_hc = HBoxContainer.new()
	claim_hc.add_theme_constant_override("separation", 12)
	claim_center.add_child(claim_hc)
	
	var claim_icon = UIIcon.new(UIIcon.Type.REWARD, UITheme.BLACK, 24)
	claim_hc.add_child(claim_icon)
	var claim_lbl = Label.new()
	claim_lbl.text = "CLAIM"
	claim_lbl.label_settings = UITheme.ls_button(UITheme.BLACK)
	claim_hc.add_child(claim_lbl)
	
	_claim_btn.pressed.connect(_on_claim_pressed)
	_btns_hbox.add_child(_claim_btn)

	_watch_ad_btn = Button.new()
	_watch_ad_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_watch_ad_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_MD)
	_watch_ad_btn.add_theme_stylebox_override("normal",  UITheme.btn_secondary(UITheme.GOLD))
	_watch_ad_btn.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed())
	
	var wa_center = CenterContainer.new()
	wa_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_watch_ad_btn.add_child(wa_center)
	var wa_hc = HBoxContainer.new()
	wa_hc.add_theme_constant_override("separation", 12)
	wa_center.add_child(wa_hc)
	
	var wa_icon = UIIcon.new(UIIcon.Type.PLAY, UITheme.GOLD, 20)
	wa_hc.add_child(wa_icon)
	var wa_lbl = Label.new()
	wa_lbl.text = "WATCH AD (2X)"
	wa_lbl.label_settings = UITheme.ls_title_font(18, UITheme.GOLD)
	wa_hc.add_child(wa_lbl)
	
	_watch_ad_btn.pressed.connect(_on_watch_ad_pressed)
	_btns_hbox.add_child(_watch_ad_btn)
	
	_btns_hbox.hide()

	DailyChallengeManager.progress_updated.connect(_refresh_ui)
	_refresh_ui()

func _make_divider() -> Control:
	var div = PanelContainer.new()
	div.custom_minimum_size = Vector2(0, 1)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	div.add_theme_stylebox_override("panel", sb)
	return div


func _refresh_ui() -> void:
	if not _desc_label: return
	var c = DailyChallengeManager.current_challenge
	if c.is_empty(): return

	_desc_label.text = c["desc"]
	var prog = DailyChallengeManager.progress
	var tgt  = c["target"]
	_progress_nums.text = "%d / %d" % [prog, tgt]
	_reward_label.text = "+%d" % c["reward"]

	var ratio = clampf(float(prog) / float(max(tgt, 1)), 0.0, 1.0)
	# _progress_fill is a Control whose width is set as a fraction of its parent
	var track = _progress_fill.get_parent()
	if track:
		var target_w = track.size.x * ratio
		var tween = create_tween()
		tween.tween_property(_progress_fill, "size:x", target_w, 0.4).set_ease(Tween.EASE_OUT)
	else:
		_progress_fill.size.x = _progress_fill.get_parent_rect().size.x * ratio if _progress_fill.get_parent() else 0.0

	var fill_color = UITheme.SUCCESS if DailyChallengeManager.completed else UITheme.CYAN
	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.set_corner_radius_all(8)
	fill_sb.shadow_color = Color(fill_color, 0.5)
	fill_sb.shadow_size = 8
	# Apply to inner PanelContainer (fill_draw)
	if _progress_fill.get_child_count() > 0:
		_progress_fill.get_child(0).add_theme_stylebox_override("panel", fill_sb)

	if DailyChallengeManager.claimed:
		_status_label.text = "REWARD CLAIMED"
		_status_label.label_settings = UITheme.ls_title_font(16, UITheme.SUCCESS)
		_status_label.show(); _btns_hbox.hide()
	elif DailyChallengeManager.completed:
		_status_label.hide(); _btns_hbox.show()
	else:
		_status_label.text = "IN PROGRESS"
		_status_label.label_settings = UITheme.ls(16, UITheme.MUTED)
		_status_label.show(); _btns_hbox.hide()


func _on_claim_pressed() -> void:
	AudioManager.play(AudioManager.SND_REWARD)
	DailyChallengeManager.claim_reward()

func _on_watch_ad_pressed() -> void:
	AudioManager.play(AudioManager.SND_BUTTON)
	AdManager.show_rewarded("daily_2x")
