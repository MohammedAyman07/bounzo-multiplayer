extends Control

# =====================================================
# SHOP UI — Premium Redesign
# =====================================================

var _balls_tab: ScrollContainer
var _trails_tab: ScrollContainer
var _current_tab: String = "balls"
var _balls_btn: Button
var _trails_btn: Button

func _ready() -> void:
	name = "ShopPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport_rect().size)
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(UITheme.BG, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── ROOT VBOX ─────────────────────────────────────────
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# ── HEADER ───────────────────────────────────────────
	var hdr_m = MarginContainer.new()
	hdr_m.add_theme_constant_override("margin_left",  20)
	hdr_m.add_theme_constant_override("margin_right", 20)
	hdr_m.add_theme_constant_override("margin_top",   20)
	hdr_m.add_theme_constant_override("margin_bottom", 10)
	root_vbox.add_child(hdr_m)

	var header = UITheme.make_header("SHOP", true, true, func():
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

	# ── TABS ──────────────────────────────────────────────
	var tab_m = MarginContainer.new()
	tab_m.add_theme_constant_override("margin_left",  20)
	tab_m.add_theme_constant_override("margin_right", 20)
	tab_m.add_theme_constant_override("margin_bottom", 12)
	root_vbox.add_child(tab_m)

	var tab_panel = PanelContainer.new()
	tab_panel.add_theme_stylebox_override("panel", UITheme.glass_panel(UITheme.RADIUS_LG))
	tab_m.add_child(tab_panel)

	var tab_hbox = HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 0)
	tab_panel.add_child(tab_hbox)

	_balls_btn  = _make_tab_btn("BALLS")
	_trails_btn = _make_tab_btn("TRAILS")
	tab_hbox.add_child(_balls_btn)
	tab_hbox.add_child(_trails_btn)
	_balls_btn.pressed.connect(_switch_to_balls)
	_trails_btn.pressed.connect(_switch_to_trails)

	# ── SCROLL GRIDS ────────────────────────────────────
	_balls_tab  = _build_grid(CosmeticData.BALLS,  "ball")
	_trails_tab = _build_grid(CosmeticData.TRAILS, "trail")
	_balls_tab.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	_trails_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL

	root_vbox.add_child(_balls_tab)
	root_vbox.add_child(_trails_tab)

	_switch_to_balls()


func _make_tab_btn(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	return btn


func _set_tab_active(btn: Button, active: bool) -> void:
	if active:
		var sb = StyleBoxFlat.new()
		sb.bg_color = UITheme.CYAN
		sb.set_corner_radius_all(UITheme.RADIUS_LG)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_color_override("font_color", UITheme.BLACK)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(UITheme.RADIUS_LG)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_color_override("font_color", UITheme.MUTED)


func _switch_to_balls() -> void:
	_current_tab = "balls"
	if _balls_tab: _balls_tab.show()
	if _trails_tab: _trails_tab.hide()
	if _balls_btn and _trails_btn:
		_set_tab_active(_balls_btn, true)
		_set_tab_active(_trails_btn, false)


func _switch_to_trails() -> void:
	_current_tab = "trails"
	if _balls_tab: _balls_tab.hide()
	if _trails_tab: _trails_tab.show()
	if _balls_btn and _trails_btn:
		_set_tab_active(_balls_btn, false)
		_set_tab_active(_trails_btn, true)


func _build_grid(data_dict: Dictionary, type: String) -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var grid_m = MarginContainer.new()
	grid_m.name = "GridMargin"
	grid_m.add_theme_constant_override("margin_left",  20)
	grid_m.add_theme_constant_override("margin_right", 20)
	grid_m.add_theme_constant_override("margin_top",   12)
	grid_m.add_theme_constant_override("margin_bottom",20)
	grid_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_m)

	var grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_m.add_child(grid)

	var items = data_dict.values()
	items.sort_custom(func(a, b): return a["price"] < b["price"])
	for item in items:
		grid.add_child(_build_card(item, type))

	return scroll


func _get_rarity_info(price: int) -> Dictionary:
	if price == 0:
		return {"text": "COMMON", "color": UITheme.MUTED}
	elif price <= 500:
		return {"text": "RARE", "color": UITheme.CYAN}
	elif price <= 2000:
		return {"text": "EPIC", "color": UITheme.PURPLE}
	else:
		return {"text": "LEGENDARY", "color": UITheme.GOLD}


func _get_preview_type(item_id: String) -> int:
	match item_id:
		"basic": return CosmeticPreview.Type.BASIC
		"fire": return CosmeticPreview.Type.FIRE
		"lightning": return CosmeticPreview.Type.LIGHTNING
		"crystal": return CosmeticPreview.Type.CRYSTAL
		"shadow": return CosmeticPreview.Type.SHADOW
		"neon": return CosmeticPreview.Type.NEON
		_: return CosmeticPreview.Type.BASIC


func _build_card(item: Dictionary, type: String) -> PanelContainer:
	var item_id   = item.get("id", "")
	var is_owned  = false
	var is_equipped = false
	var price = item.get("price", 0)

	if type == "ball":
		is_owned    = SaveManager.data["unlocked_balls"].has(item_id)
		is_equipped = SaveManager.data["selected_ball"] == item_id
	else:
		is_owned    = SaveManager.data["unlocked_trails"].has(item_id)
		is_equipped = SaveManager.data["selected_trail"] == item_id

	var card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size = Vector2(0, 240)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_sb = UITheme.glass_panel(UITheme.RADIUS_MD)
	if is_equipped:
		card_sb = UITheme.glass_panel_accent(UITheme.SUCCESS, UITheme.RADIUS_MD)
	elif is_owned:
		card_sb = UITheme.glass_panel_accent(UITheme.CYAN, UITheme.RADIUS_MD)
		
	card.add_theme_stylebox_override("panel", card_sb)

	var card_m = MarginContainer.new()
	card_m.add_theme_constant_override("margin_left",  12)
	card_m.add_theme_constant_override("margin_right", 12)
	card_m.add_theme_constant_override("margin_top",   16)
	card_m.add_theme_constant_override("margin_bottom", 12)
	card.add_child(card_m)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card_m.add_child(vbox)

	# 1. Preview
	var preview_cont = CenterContainer.new()
	preview_cont.custom_minimum_size = Vector2(80, 80)
	preview_cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	if is_owned or type == "ball":
		var cp = CosmeticPreview.new(_get_preview_type(item_id))
		preview_cont.add_child(cp)
	else:
		var lck = UIIcon.new(UIIcon.Type.LOCK, UITheme.MUTED, 40)
		preview_cont.add_child(lck)
		
	vbox.add_child(preview_cont)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# 2. Name
	var name_lbl = Label.new()
	name_lbl.text = item.get("name", item_id).to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.label_settings = UITheme.ls_title_font(16, UITheme.WHITE)
	vbox.add_child(name_lbl)

	# 3. Rarity
	var rarity = _get_rarity_info(price)
	var rarity_lbl = Label.new()
	rarity_lbl.text = rarity["text"]
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.label_settings = UITheme.ls(12, rarity["color"])
	vbox.add_child(rarity_lbl)

	# 4. Action Button (Contains price or state)
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
	btn.size_flags_horizontal = Control.SIZE_FILL
	
	var hc_center = CenterContainer.new()
	hc_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(hc_center)

	var hc = HBoxContainer.new()
	hc.add_theme_constant_override("separation", 6)
	hc_center.add_child(hc)

	if is_equipped:
		btn.add_theme_stylebox_override("normal", UITheme.glass_panel_accent(UITheme.SUCCESS, UITheme.RADIUS_SM))
		hc.add_child(UIIcon.new(UIIcon.Type.CHECK, UITheme.SUCCESS, 16))
		var l = Label.new()
		l.text = "EQUIPPED"
		l.label_settings = UITheme.ls_title_font(14, UITheme.SUCCESS)
		hc.add_child(l)
	elif is_owned:
		btn.add_theme_stylebox_override("normal", UITheme.glass_panel_accent(UITheme.MUTED, UITheme.RADIUS_SM))
		btn.add_theme_stylebox_override("hover", UITheme.glass_panel_accent(UITheme.WHITE, UITheme.RADIUS_SM))
		var l = Label.new()
		l.text = "EQUIP"
		l.label_settings = UITheme.ls_title_font(14, UITheme.WHITE)
		hc.add_child(l)
	else:
		btn.add_theme_stylebox_override("normal", UITheme.btn_primary(UITheme.RADIUS_SM))
		btn.add_theme_stylebox_override("pressed", UITheme.btn_primary_pressed(UITheme.RADIUS_SM))
		var price_l = Label.new()
		if price == 0:
			price_l.text = "FREE"
			price_l.label_settings = UITheme.ls_title_font(16, UITheme.BLACK)
		else:
			hc.add_child(UIIcon.new(UIIcon.Type.COIN, UITheme.BLACK, 16))
			price_l.text = str(price)
			price_l.label_settings = UITheme.ls_button(UITheme.BLACK)
		hc.add_child(price_l)

	vbox.add_child(btn)

	btn.pressed.connect(func():
		var currently_owned = false
		if type == "ball":
			currently_owned = SaveManager.data.get("unlocked_balls", []).has(item_id)
		else:
			currently_owned = SaveManager.data.get("unlocked_trails", []).has(item_id)
			
		if currently_owned:
			if type == "ball":
				SaveManager.data["selected_ball"] = item_id
			else:
				SaveManager.data["selected_trail"] = item_id
			SaveManager.save_data()
			AudioManager.play(AudioManager.SND_EQUIP)
			_refresh_all_cards()
		else:
			var cost = item.get("price", 0)
			# Re-verify the item isn't somehow already owned to prevent double charges
			if currently_owned:
				return
				
			if CurrencyManager.can_afford(cost):
				if CurrencyManager.spend_coins(cost):
					if type == "ball":
						SaveManager.data["unlocked_balls"].append(item_id)
						SaveManager.data["selected_ball"] = item_id
					else:
						SaveManager.data["unlocked_trails"].append(item_id)
						SaveManager.data["selected_trail"] = item_id
					SaveManager.save_data()
					AudioManager.play(AudioManager.SND_PURCHASE)
					_refresh_all_cards()
			else:
				AudioManager.play(AudioManager.SND_ERROR)
				_show_not_enough_coins_popup(cost)
	)

	return card

func _show_not_enough_coins_popup(cost: int) -> void:
	if get_node_or_null("NotEnoughCoinsBG"):
		return
		
	var popup_bg = ColorRect.new()
	popup_bg.name = "NotEnoughCoinsBG"
	popup_bg.color = Color(0, 0, 0, 0.8)
	popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(popup_bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_bg.add_child(center)
	
	var pnl = PanelContainer.new()
	var sb = UITheme.glass_panel_challenges(UITheme.MAGENTA, 16)
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
	lbl1.label_settings = UITheme.ls_title_font(24, UITheme.CYAN)
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl1)
	
	var lbl2 = Label.new()
	var current = CurrencyManager.get_coins()
	var short_by = cost - current
	lbl2.text = "YOU NEED:\n%d COINS\n\nYOU HAVE:\n%d COINS\n\nSHORT BY:\n%d COINS" % [cost, current, short_by]
	lbl2.label_settings = UITheme.ls(16, UITheme.WHITE)
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl2)
	
	var ad_btn = UITheme.make_filled_button("WATCH AD\n+100 COINS", UITheme.GOLD)
	ad_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		AdManager.show_rewarded("free_coins_100")
	)
	vbox.add_child(ad_btn)
	
	var close_btn = UITheme.make_button("CANCEL", UITheme.MUTED)
	close_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SND_BUTTON)
		popup_bg.queue_free()
	)
	vbox.add_child(close_btn)

func _refresh_all_cards() -> void:
	if _balls_tab:
		var bg = _balls_tab.get_node("GridMargin/Grid")
		for c in bg.get_children():
			bg.remove_child(c)
			c.queue_free()
		var items = CosmeticData.BALLS.values()
		items.sort_custom(func(a, b): return a["price"] < b["price"])
		for item in items:
			bg.add_child(_build_card(item, "ball"))

	if _trails_tab:
		var tg = _trails_tab.get_node("GridMargin/Grid")
		for c in tg.get_children():
			tg.remove_child(c)
			c.queue_free()
		var items = CosmeticData.TRAILS.values()
		items.sort_custom(func(a, b): return a["price"] < b["price"])
		for item in items:
			tg.add_child(_build_card(item, "trail"))
