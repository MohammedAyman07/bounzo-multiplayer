extends Control

# =====================================================
# CHALLENGES UI
# =====================================================

var _scroll_vbox: VBoxContainer
var _banner_container: VBoxContainer

var viewing_rank_id: String = ""
var _is_starting: bool = false
var _rank_transition_tween: Tween

func _ready() -> void:
	name = "ChallengesPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport_rect().size)
	_build_ui()
	
	visibility_changed.connect(func():
		if visible:
			if viewing_rank_id == "":
				viewing_rank_id = ChallengeManager.get_current_rank().id
			_refresh_ui()
	)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(UITheme.BG, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# HEADER
	var hdr_m = MarginContainer.new()
	hdr_m.add_theme_constant_override("margin_left", 20)
	hdr_m.add_theme_constant_override("margin_right", 20)
	hdr_m.add_theme_constant_override("margin_top", 20)
	hdr_m.add_theme_constant_override("margin_bottom", 20)
	root_vbox.add_child(hdr_m)

	var header = UITheme.make_header("CHALLENGES", true, true, func():
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
			if is_instance_valid(coins_cap):
				var l = coins_cap.find_child("CoinLabel", true, false)
				if l: l.text = str(amt)
		)

	# MASTERY BANNER
	var banner_m = MarginContainer.new()
	banner_m.add_theme_constant_override("margin_left", 20)
	banner_m.add_theme_constant_override("margin_right", 20)
	banner_m.add_theme_constant_override("margin_bottom", 10)
	root_vbox.add_child(banner_m)
	
	_banner_container = VBoxContainer.new()
	_banner_container.name = "BannerContainer"
	banner_m.add_child(_banner_container)

	# SCROLL AREA
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var content_m = MarginContainer.new()
	content_m.add_theme_constant_override("margin_left", 24)
	content_m.add_theme_constant_override("margin_right", 24)
	content_m.add_theme_constant_override("margin_top", 10)
	content_m.add_theme_constant_override("margin_bottom", 24)
	content_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_m)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.add_theme_constant_override("separation", 16)
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_m.add_child(_scroll_vbox)

func _refresh_ui() -> void:
	for child in _scroll_vbox.get_children():
		child.queue_free()
	for child in _banner_container.get_children():
		child.queue_free()
		
	if viewing_rank_id == "":
		viewing_rank_id = ChallengeManager.get_current_rank().id
		
	_build_rank_banner()
		
	# Test Mode Label
	if ChallengeManager.CHALLENGE_TEST_MODE:
		var tm_lbl = Label.new()
		tm_lbl.text = "TEST MODE — FREE ENTRY"
		tm_lbl.label_settings = UITheme.ls_title_font(16, UITheme.GOLD)
		tm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_scroll_vbox.add_child(tm_lbl)

	if ChallengeManager.is_rank_unlocked(viewing_rank_id):
		var chal_ids = ChallengeManager.get_challenges_for_rank(viewing_rank_id)
		for chal_id in chal_ids:
			_build_challenge_card(ChallengeManager.CHALLENGES[chal_id])

func _get_rank_index(id: String) -> int:
	for i in range(ChallengeManager.RANKS.size()):
		if ChallengeManager.RANKS[i].id == id:
			return i
	return 0

func _build_rank_banner() -> void:
	var rank = ChallengeManager.get_rank_by_id(viewing_rank_id)
	var next_rank = ChallengeManager.get_next_rank(viewing_rank_id)
	var current_stars = ChallengeManager.get_stars_in_rank(viewing_rank_id)
	var is_unlocked = ChallengeManager.is_rank_unlocked(viewing_rank_id)
	
	var pnl = PanelContainer.new()
	pnl.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb = StyleBoxFlat.new()
	sb.bg_color = UITheme.SURFACE_LT
	sb.border_color = rank.color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	pnl.add_theme_stylebox_override("panel", sb)
	_banner_container.add_child(pnl)
	
	# CENTER VBOX is now the root
	var center_vbox = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 12)
	pnl.add_child(center_vbox)
	
	# CURRENT/VIEWING
	var status_lbl = Label.new()
	if viewing_rank_id == ChallengeManager.get_current_rank().id:
		status_lbl.text = "CURRENT"
		status_lbl.label_settings = UITheme.ls(12, UITheme.BG)
		var stat_sb = StyleBoxFlat.new()
		stat_sb.bg_color = UITheme.CYAN
		stat_sb.set_corner_radius_all(10)
		stat_sb.content_margin_left = 8
		stat_sb.content_margin_right = 8
		stat_sb.content_margin_top = 2
		stat_sb.content_margin_bottom = 2
		var stat_pnl = PanelContainer.new()
		stat_pnl.add_theme_stylebox_override("panel", stat_sb)
		stat_pnl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stat_pnl.add_child(status_lbl)
		center_vbox.add_child(stat_pnl)
	else:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 16)
		center_vbox.add_child(spacer)
		
	# RANK NAME
	var title_lbl = Label.new()
	title_lbl.text = rank.name
	title_lbl.label_settings = UITheme.ls_title_font(28, rank.color)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(title_lbl)
	
	# EMBLEM ROW
	var emblem_hbox = HBoxContainer.new()
	emblem_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	emblem_hbox.add_theme_constant_override("separation", 16)
	center_vbox.add_child(emblem_hbox)
	
	var idx = _get_rank_index(viewing_rank_id)
	
	# LEFT ARROW
	var btn_left = Button.new()
	btn_left.text = "‹"
	btn_left.add_theme_font_size_override("font_size", 28)
	btn_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_left.custom_minimum_size = Vector2(48, 48)
	var sb_left = StyleBoxFlat.new()
	sb_left.bg_color = Color(0, 0, 0, 0.4)
	sb_left.border_color = UITheme.CYAN
	sb_left.set_border_width_all(2)
	sb_left.set_corner_radius_all(24)
	
	if idx == 0:
		sb_left.border_color = Color(0.3, 0.3, 0.3)
		btn_left.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	else:
		btn_left.add_theme_color_override("font_color", UITheme.CYAN)
		
	btn_left.add_theme_stylebox_override("normal", sb_left)
	btn_left.add_theme_stylebox_override("hover", sb_left)
	btn_left.add_theme_stylebox_override("pressed", sb_left)
	btn_left.add_theme_stylebox_override("focus", sb_left)
	btn_left.add_theme_stylebox_override("disabled", sb_left)
	
	btn_left.pressed.connect(func():
		if idx > 0:
			_navigate_rank(idx - 1, btn_left)
	)
	emblem_hbox.add_child(btn_left)
	
	# EMBLEM
	var emblem = UITheme.make_rank_emblem(rank, 160)
	emblem_hbox.add_child(emblem)
	
	# RIGHT ARROW
	var btn_right = Button.new()
	btn_right.text = "›"
	btn_right.add_theme_font_size_override("font_size", 28)
	btn_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_right.custom_minimum_size = Vector2(48, 48)
	var sb_right = StyleBoxFlat.new()
	sb_right.bg_color = Color(0, 0, 0, 0.4)
	sb_right.border_color = UITheme.CYAN
	sb_right.set_border_width_all(2)
	sb_right.set_corner_radius_all(24)
	
	if idx == ChallengeManager.RANKS.size() - 1:
		sb_right.border_color = Color(0.3, 0.3, 0.3)
		btn_right.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	else:
		btn_right.add_theme_color_override("font_color", UITheme.CYAN)
		
	btn_right.add_theme_stylebox_override("normal", sb_right)
	btn_right.add_theme_stylebox_override("hover", sb_right)
	btn_right.add_theme_stylebox_override("pressed", sb_right)
	btn_right.add_theme_stylebox_override("focus", sb_right)
	btn_right.add_theme_stylebox_override("disabled", sb_right)
	
	btn_right.pressed.connect(func():
		if idx < ChallengeManager.RANKS.size() - 1:
			_navigate_rank(idx + 1, btn_right)
	)
	emblem_hbox.add_child(btn_right)
	
	# STARS AND PROGRESS
	if is_unlocked:
		var star_icons_hbox = HBoxContainer.new()
		star_icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		center_vbox.add_child(star_icons_hbox)
		
		for i in range(rank.required_stars):
			var s_lbl = Label.new()
			if i < current_stars:
				s_lbl.text = "★"
				s_lbl.label_settings = UITheme.ls_glow_title(36, rank.color, rank.color)
			else:
				s_lbl.text = "☆"
				s_lbl.label_settings = UITheme.ls_title_font(36, Color(0.3, 0.3, 0.3))
			star_icons_hbox.add_child(s_lbl)
		
		var info_lbl = Label.new()
		if current_stars >= rank.required_stars:
			info_lbl.text = "%d / %d STARS (MAX)" % [current_stars, rank.required_stars]
		else:
			info_lbl.text = "%d / %d STARS" % [current_stars, rank.required_stars]
		info_lbl.label_settings = UITheme.ls(14, UITheme.WHITE)
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_vbox.add_child(info_lbl)
		
		var pbar = ProgressBar.new()
		pbar.max_value = rank.required_stars
		pbar.value = current_stars
		pbar.custom_minimum_size = Vector2(160, 8)
		pbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pbar.show_percentage = false
		var bg_sb = StyleBoxFlat.new()
		bg_sb.bg_color = Color(0,0,0,0.5)
		bg_sb.set_corner_radius_all(4)
		var fg_sb = StyleBoxFlat.new()
		fg_sb.bg_color = rank.color
		fg_sb.set_corner_radius_all(4)
		pbar.add_theme_stylebox_override("background", bg_sb)
		pbar.add_theme_stylebox_override("fill", fg_sb)
		center_vbox.add_child(pbar)
		
		# NEXT RANK
		if rank.id != next_rank.id:
			var nxt_pnl = VBoxContainer.new()
			nxt_pnl.add_theme_constant_override("separation", 2)
			var n1 = Label.new()
			n1.text = "NEXT RANK"
			n1.label_settings = UITheme.ls(12, UITheme.MUTED)
			n1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var n2 = Label.new()
			n2.text = next_rank.name
			n2.label_settings = UITheme.ls_title_font(18, next_rank.color)
			n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var n3 = Label.new()
			var stars_needed = rank.required_stars - current_stars
			if stars_needed > 0:
				n3.text = "%d CHALLENGES TO GO" % stars_needed
			else:
				n3.text = "UNLOCKED!"
			n3.label_settings = UITheme.ls(14, UITheme.WHITE)
			n3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nxt_pnl.add_child(n1)
			nxt_pnl.add_child(n2)
			nxt_pnl.add_child(n3)
			var spc = Control.new()
			spc.custom_minimum_size = Vector2(0, 8)
			center_vbox.add_child(spc)
			center_vbox.add_child(nxt_pnl)
	else:
		# LOCKED
		var l1 = Label.new()
		l1.text = "LOCKED"
		l1.label_settings = UITheme.ls_title_font(24, UITheme.MUTED)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_vbox.add_child(l1)
		
		var prev_rank = ChallengeManager.RANKS[idx - 1]
		var l2 = Label.new()
		l2.text = "COMPLETE %s SET" % prev_rank.name
		l2.label_settings = UITheme.ls(16, prev_rank.color)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_vbox.add_child(l2)
		
		var prev_stars = ChallengeManager.get_stars_in_rank(prev_rank.id)
		var l3 = Label.new()
		l3.text = "%d / %d REQUIRED" % [prev_stars, prev_rank.required_stars]
		l3.label_settings = UITheme.ls(14, UITheme.WHITE)
		l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_vbox.add_child(l3)

func _navigate_rank(new_idx: int, btn: Button) -> void:
	AudioManager.play(AudioManager.SND_BUTTON)
	
	btn.pivot_offset = btn.size / 2.0
	var btn_tw = create_tween()
	btn_tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05)
	btn_tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	
	var old_idx = _get_rank_index(viewing_rank_id)
	var dir = 1 if new_idx > old_idx else -1
	viewing_rank_id = ChallengeManager.RANKS[new_idx].id
	
	if is_instance_valid(_rank_transition_tween):
		_rank_transition_tween.kill()
	_rank_transition_tween = create_tween()
	_rank_transition_tween.set_parallel(true)
	
	var center_vbox = _banner_container.get_child(0).get_child(0)
	
	_rank_transition_tween.tween_property(center_vbox, "modulate:a", 0.0, 0.1)
	_rank_transition_tween.tween_property(center_vbox, "position:x", center_vbox.position.x - (10 * dir), 0.1)
	
	_rank_transition_tween.chain().tween_callback(func():
		_refresh_ui()
		if _banner_container.get_child_count() > 0:
			var new_center = _banner_container.get_child(0).get_child(0)
			new_center.modulate.a = 0.0
			new_center.position.x += (10 * dir)
			
			var tw2 = create_tween().set_parallel(true)
			tw2.tween_property(new_center, "modulate:a", 1.0, 0.15)
			tw2.tween_property(new_center, "position:x", new_center.position.x - (10 * dir), 0.15)
			
			var emblem_row = null
			for child in new_center.get_children():
				if child is HBoxContainer:
					emblem_row = child
					break
			if emblem_row:
				for child in emblem_row.get_children():
					if child is CenterContainer: # emblem
						child.pivot_offset = Vector2(60, 60) # half of 120
						child.scale = Vector2(0.9, 0.9)
						tw2.tween_property(child, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						break
	)

func _build_challenge_card(chal: Dictionary) -> void:
	var card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb = StyleBoxFlat.new()
	sb.bg_color = UITheme.SURFACE
	sb.border_color = UITheme.CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	# Top: Name & Difficulty
	var hbox1 = HBoxContainer.new()
	var title = Label.new()
	title.text = chal.name
	title.label_settings = UITheme.ls_title_font(24, UITheme.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox1.add_child(title)
	
	var diff = Label.new()
	diff.text = chal.difficulty
	diff.label_settings = UITheme.ls(16, UITheme.MAGENTA)
	hbox1.add_child(diff)
	vbox.add_child(hbox1)
	
	# Target & Time
	var hbox2 = HBoxContainer.new()
	var target_lbl = Label.new()
	target_lbl.text = "TARGET: " + str(chal.target)
	target_lbl.label_settings = UITheme.ls(18, UITheme.CYAN)
	target_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox2.add_child(target_lbl)
	
	var time_lbl = Label.new()
	time_lbl.text = "TIME: %d:%02d" % [int(chal.time) / 60, int(chal.time) % 60]
	time_lbl.label_settings = UITheme.ls(18, UITheme.WHITE)
	hbox2.add_child(time_lbl)
	vbox.add_child(hbox2)
	
	# Bottom Info: Entry & Reward
	var hbox3 = HBoxContainer.new()
	var entry_v = VBoxContainer.new()
	var entry_t = Label.new()
	entry_t.text = "ENTRY"
	entry_t.label_settings = UITheme.ls(12, UITheme.MUTED)
	var entry_val = Label.new()
	if ChallengeManager.CHALLENGE_TEST_MODE:
		entry_val.text = "FREE"
		entry_val.label_settings = UITheme.ls_title_font(20, UITheme.CYAN)
	else:
		entry_val.text = "🪙 " + str(chal.entry)
		entry_val.label_settings = UITheme.ls_title_font(20, UITheme.GOLD)
	entry_v.add_child(entry_t)
	entry_v.add_child(entry_val)
	entry_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox3.add_child(entry_v)
	
	var rew_v = VBoxContainer.new()
	var rew_t = Label.new()
	rew_t.text = "REWARD"
	rew_t.label_settings = UITheme.ls(12, UITheme.MUTED)
	var rew_val = Label.new()
	rew_val.text = "🪙 " + str(chal.reward)
	rew_val.label_settings = UITheme.ls_title_font(20, UITheme.GOLD)
	rew_v.add_child(rew_t)
	rew_v.add_child(rew_val)
	rew_v.alignment = BoxContainer.ALIGNMENT_END
	hbox3.add_child(rew_v)
	vbox.add_child(hbox3)
	
	# Mastery Info: Star Value & Best Score
	var hbox4 = HBoxContainer.new()
	var xp_v = VBoxContainer.new()
	var xp_t = Label.new()
	xp_t.text = "STAR VALUE"
	xp_t.label_settings = UITheme.ls(12, UITheme.MUTED)
	var xp_val = Label.new()
	xp_val.text = "★ +%d" % chal.star_value
	xp_val.label_settings = UITheme.ls_title_font(20, UITheme.CYAN)
	xp_v.add_child(xp_t)
	xp_v.add_child(xp_val)
	xp_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox4.add_child(xp_v)
	
	var bests = SaveManager.data.get("challenge_best_scores", {})
	var best_score = bests.get(chal.id, 0)
	
	var best_v = VBoxContainer.new()
	var best_t = Label.new()
	best_t.text = "BEST SCORE"
	best_t.label_settings = UITheme.ls(12, UITheme.MUTED)
	var best_val = Label.new()
	best_val.text = str(best_score)
	best_val.label_settings = UITheme.ls_title_font(20, UITheme.WHITE)
	best_v.add_child(best_t)
	best_v.add_child(best_val)
	best_v.alignment = BoxContainer.ALIGNMENT_END
	hbox4.add_child(best_v)
	vbox.add_child(hbox4)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Status Indicator
	var comps = SaveManager.data.get("challenge_completion_status", {})
	var status_lbl = Label.new()
	if comps.get(chal.id, false):
		status_lbl.text = "✓ COMPLETED"
		status_lbl.label_settings = UITheme.ls_title_font(20, UITheme.SUCCESS)
	else:
		status_lbl.text = "NOT STARTED"
		status_lbl.label_settings = UITheme.ls_title_font(16, UITheme.MUTED)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_lbl)
	vbox.add_child(spacer)
	
	# Start Button
	var is_completed = comps.get(chal.id, false)
	if not is_completed:
		var start_btn = UITheme.make_button("START", UITheme.CYAN)
		start_btn.pressed.connect(func():
			AudioManager.play(AudioManager.SND_BUTTON)
			_attempt_start(chal.id)
		)
		vbox.add_child(start_btn)
	
	_scroll_vbox.add_child(card)

func _attempt_start(chal_id: String) -> void:
	if _is_starting: return
	
	if not ChallengeManager.CHALLENGES.has(chal_id): return
	var chal = ChallengeManager.CHALLENGES[chal_id]
	if not ChallengeManager.is_rank_unlocked(chal.rank): return
	
	var comps = SaveManager.data.get("challenge_completion_status", {})
	if comps.get(chal_id, false): return
	
	if ChallengeManager.is_active(): return
	
	_is_starting = true
	
	var fee = ChallengeManager.get_effective_entry_fee(chal_id)
	if fee > 0 and not CurrencyManager.can_afford(fee):
		_show_not_enough_coins(chal_id)
		_is_starting = false
		return
	
	var game_node = get_tree().root.get_node_or_null("Game")
	if not game_node or not game_node.has_method("_start_game"):
		_is_starting = false
		return
		
	if fee > 0:
		if not CurrencyManager.spend_coins(fee):
			_is_starting = false
			return
		
	ChallengeManager.start_challenge(chal_id)
	game_node._start_game()
		
	hide()
	
	# The game node will reset state on game over.
	# We can reset the lock immediately since hide() makes the UI unclickable
	# and we just successfully handed off execution to _start_game().
	_is_starting = false

func _show_not_enough_coins(chal_id: String) -> void:
	var popup_bg = ColorRect.new()
	popup_bg.name = "NotEnoughCoinsBG"
	popup_bg.color = Color(0, 0, 0, 0.8)
	popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(popup_bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_bg.add_child(center)
	
	var pnl = PanelContainer.new()
	var sb = UITheme.glass_panel_challenges(UITheme.CYAN, 16)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	pnl.add_child(vbox)
	
	var lbl1 = Label.new()
	lbl1.text = "NOT ENOUGH COINS"
	lbl1.label_settings = UITheme.ls_title_font(24, UITheme.MAGENTA)
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl1)
	
	var lbl2 = Label.new()
	var fee = ChallengeManager.get_effective_entry_fee(chal_id)
	var current = CurrencyManager.get_coins()
	var short_by = fee - current
	lbl2.text = "YOU NEED:\n%d COINS\n\nYOU HAVE:\n%d COINS\n\nSHORT BY:\n%d COINS" % [fee, current, short_by]
	lbl2.label_settings = UITheme.ls(16, UITheme.WHITE)
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl2)
	
	var watch_btn = UITheme.make_filled_button("WATCH AD\n+100 COINS", UITheme.GOLD)
	watch_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		AdManager.show_rewarded("free_coins_100")
	)
	vbox.add_child(watch_btn)
	
	var cancel_btn = UITheme.make_button("CANCEL", UITheme.MUTED)
	cancel_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		popup_bg.queue_free()
	)
	vbox.add_child(cancel_btn)
