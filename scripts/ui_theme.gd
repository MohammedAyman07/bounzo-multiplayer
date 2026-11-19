extends Node

# =====================================================
# UI THEME — Premium Design System
# =====================================================

# --- Color Palette ---
const BG          = Color(0.020, 0.012, 0.059, 1.0)  # #05030F
const SURFACE     = Color(0.043, 0.027, 0.094, 1.0)  # #0B0718
const SURFACE_LT  = Color(0.071, 0.043, 0.145, 1.0)  # #120B25
const PURPLE      = Color(0.482, 0.173, 1.000, 1.0)  # #7B2CFF
const MAGENTA     = Color(1.000, 0.125, 0.784, 1.0)  # #FF20C8
const CYAN        = Color(0.098, 0.851, 1.000, 1.0)  # #19D9FF
const YELLOW      = Color(1.000, 0.824, 0.122, 1.0)  # #FFD21F
const GOLD        = Color(1.000, 0.788, 0.157, 1.0)  # #FFC928
const WHITE       = Color(0.961, 0.961, 0.969, 1.0)  # #F5F5F7
const MUTED       = Color(0.561, 0.541, 0.608, 1.0)  # #8F8A9B
const SUCCESS     = Color(0.224, 1.000, 0.533, 1.0)  # #39FF88
const BLACK       = Color(0.0, 0.0, 0.0, 1.0)

# --- Spacing ---
const SP_XS  = 8
const SP_SM  = 12
const SP_MD  = 16
const SP_LG  = 24
const SP_XL  = 32

# --- Border radius ---
const RADIUS_SM  = 10
const RADIUS_MD  = 16
const RADIUS_LG  = 20
const RADIUS_XL  = 28

# --- Button heights ---
const BTN_H_LG  = 64
const BTN_H_MD  = 56
const BTN_H_SM  = 44

# =====================================================
# FONT ARCHITECTURE
# =====================================================
# Centralized font configuration. Future-proofed to load .ttf if needed.

static func _get_base_font() -> Font:
	return ThemeDB.fallback_font

static func get_font_logo() -> Font:
	return _get_base_font()
	
static func get_font_title() -> Font:
	return _get_base_font()
	
static func get_font_body() -> Font:
	return _get_base_font()

# =====================================================
# StyleBox Factories (Premium Depth)
# =====================================================

static func glass_panel(radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.85) # Darker inner surface
	# Premium depth: subtle gradient simulation using shadows/borders
	sb.border_color = Color(1, 1, 1, 0.1) # Top highlight
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 0
	sb.set_corner_radius_all(radius)
	# Soft outer shadow
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	return sb

static func glass_panel_accent(accent: Color = CYAN, radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = glass_panel(radius)
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	sb.border_color = Color(accent, 0.5)
	sb.border_width_bottom = 1
	return sb

static func glass_panel_challenges(base_color: Color = Color(0.0, 1.0, 1.0), radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.08, 0.95) # Even darker inner for contrast
	# Border color matches rank
	sb.border_color = Color(base_color.r, base_color.g, base_color.b, 0.65)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	# Secondary glow
	sb.shadow_color = Color(base_color.r * 0.8, base_color.g * 0.8, base_color.b * 0.8, 0.3)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 0)
	return sb

static func glass_panel_challenges_hover(base_color: Color = Color(0.0, 1.0, 1.0), radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = glass_panel_challenges(base_color, radius)
	sb.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	sb.shadow_color = Color(base_color.r, base_color.g, base_color.b, 0.5)
	sb.shadow_size = 18
	return sb

static func btn_primary(radius: int = RADIUS_LG) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = YELLOW.lightened(0.1) # Smoother yellow base
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	# Inner highlight for depth
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.border_width_top = 3
	sb.border_width_left = 1
	sb.border_width_right = 1
	# Drop shadow + subtle glow
	sb.shadow_color = Color(YELLOW, 0.4)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 8)
	return sb

static func btn_primary_pressed(radius: int = RADIUS_LG) -> StyleBoxFlat:
	var sb = btn_primary(radius)
	sb.bg_color = YELLOW.darkened(0.1)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.border_width_top = 1
	return sb

static func btn_secondary(accent: Color = CYAN, radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(SURFACE_LT, 0.1) # Compact premium outline
	sb.border_color = Color(accent, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(accent, 0.1)
	sb.shadow_size = 4
	return sb

static func btn_secondary_hover(accent: Color = CYAN, radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = btn_secondary(accent, radius)
	sb.bg_color = Color(accent, 0.2)
	sb.border_color = Color(accent, 1.0)
	sb.shadow_color = Color(accent, 0.3)
	sb.shadow_size = 8
	return sb

static func btn_filled(accent: Color = CYAN, radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
	sb.border_color = accent
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.2)
	sb.shadow_size = 12
	return sb

static func btn_filled_hover(accent: Color = CYAN, radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = btn_filled(accent, radius)
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.4)
	sb.shadow_size = 18
	return sb

static func btn_tertiary(radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(SURFACE, 0.7)
	sb.border_color = Color(MUTED, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb

static func dark_overlay() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8) # 80% opacity for depth
	return sb


# =====================================================
# Label Settings Factories
# =====================================================

static func ls(size: int, color: Color) -> LabelSettings:
	var s = LabelSettings.new()
	s.font = _get_base_font()
	s.font_size = size
	s.font_color = color
	return s

static func ls_title_font(size: int, color: Color) -> LabelSettings:
	var s = LabelSettings.new()
	s.font = get_font_title()
	s.font_size = size
	s.font_color = color
	return s

static func ls_logo_font(size: int, color: Color) -> LabelSettings:
	var s = LabelSettings.new()
	s.font = get_font_logo()
	s.font_size = size
	s.font_color = color
	return s

static func ls_glow(size: int, color: Color, glow_color: Color = Color.TRANSPARENT) -> LabelSettings:
	var s = ls(size, color)
	if glow_color != Color.TRANSPARENT:
		s.shadow_color = Color(glow_color, 0.7)
		s.shadow_size = 10
		s.outline_size = 2
		s.outline_color = Color.BLACK
	return s

static func ls_glow_title(size: int, color: Color, glow_color: Color = Color.TRANSPARENT) -> LabelSettings:
	var s = ls_title_font(size, color)
	if glow_color != Color.TRANSPARENT:
		s.shadow_color = Color(glow_color, 0.7)
		s.shadow_size = 10
		s.outline_size = 2
		s.outline_color = Color.BLACK
	return s

static func ls_glow_logo(size: int, color: Color, glow_color: Color = Color.TRANSPARENT) -> LabelSettings:
	var s = ls_logo_font(size, color)
	if glow_color != Color.TRANSPARENT:
		s.shadow_color = Color(glow_color, 0.7)
		s.shadow_size = 10
		s.outline_size = 2
		s.outline_color = Color.BLACK
	return s

static func ls_logo() -> LabelSettings:
	var s = ls_glow_logo(64, WHITE, MAGENTA)
	s.outline_size = 4
	s.outline_color = Color(0.1, 0, 0.2)
	return s

static func ls_title() -> LabelSettings:
	return ls_glow_title(36, WHITE, CYAN)

static func ls_heading() -> LabelSettings:
	return ls_title_font(24, WHITE)

static func ls_body() -> LabelSettings:
	return ls(18, WHITE)

static func ls_muted() -> LabelSettings:
	return ls(16, MUTED)

static func ls_button(color: Color = BLACK) -> LabelSettings:
	return ls_title_font(24, color)

static func ls_number(size: int = 48) -> LabelSettings:
	return ls_title_font(size, WHITE)

static func ls_yellow(size: int = 22) -> LabelSettings:
	return ls_title_font(size, YELLOW)

static func ls_cyan(size: int = 22) -> LabelSettings:
	return ls_title_font(size, CYAN)

static func ls_success(size: int = 22) -> LabelSettings:
	return ls_title_font(size, SUCCESS)


# =====================================================
# Reusable Component Builders
# =====================================================

static func make_button(text: String, accent_color: Color = CYAN) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_stylebox_override("normal", btn_secondary(accent_color, RADIUS_MD))
	btn.add_theme_stylebox_override("hover", btn_secondary_hover(accent_color, RADIUS_MD))
	btn.add_theme_stylebox_override("pressed", btn_primary_pressed(RADIUS_MD))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", get_font_title())
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", accent_color)
	btn.add_theme_color_override("font_hover_color", WHITE)
	btn.custom_minimum_size = Vector2(0, BTN_H_MD)
	return btn

static func make_filled_button(text: String, accent_color: Color = CYAN) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_stylebox_override("normal", btn_filled(accent_color, RADIUS_MD))
	btn.add_theme_stylebox_override("hover", btn_filled_hover(accent_color, RADIUS_MD))
	btn.add_theme_stylebox_override("pressed", btn_primary_pressed(RADIUS_MD))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", get_font_title())
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", WHITE)
	btn.custom_minimum_size = Vector2(0, BTN_H_MD)
	return btn

static func make_coin_capsule(coins: int, with_plus: bool = false, plus_action: Callable = Callable()) -> PanelContainer:
	var cap = PanelContainer.new()
	var cap_sb = StyleBoxFlat.new()
	cap_sb.bg_color = Color(0.04, 0.01, 0.12, 0.85)
	cap_sb.border_color = Color(GOLD, 0.5)
	cap_sb.set_border_width_all(1)
	cap_sb.set_corner_radius_all(20)
	cap_sb.shadow_color = Color(GOLD, 0.2)
	cap_sb.shadow_size = 6
	cap.add_theme_stylebox_override("panel", cap_sb)
	
	var hc = HBoxContainer.new()
	hc.add_theme_constant_override("separation", 6)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	cap.add_child(margin)
	margin.add_child(hc)
	
	var icon = UIIcon.new(UIIcon.Type.COIN, GOLD, 20)
	hc.add_child(icon)
	
	var lbl = Label.new()
	lbl.name = "CoinLabel"
	lbl.text = str(coins)
	lbl.label_settings = ls_glow_title(20, GOLD, Color(GOLD, 0.5))
	hc.add_child(lbl)
	
	if with_plus:
		var plus_btn = Button.new()
		var plus_sb = StyleBoxEmpty.new()
		plus_btn.add_theme_stylebox_override("normal", plus_sb)
		
		var plus_sb_h = StyleBoxFlat.new()
		plus_sb_h.bg_color = Color(1.0, 1.0, 1.0, 0.1)
		plus_sb_h.set_corner_radius_all(15)
		plus_btn.add_theme_stylebox_override("hover", plus_sb_h)
		plus_btn.add_theme_stylebox_override("pressed", plus_sb_h)
		plus_btn.add_theme_stylebox_override("focus", plus_sb)
		plus_btn.custom_minimum_size = Vector2(30, 30)
		
		var plus_lbl = Label.new()
		plus_lbl.text = "+"
		plus_lbl.label_settings = ls_glow_title(24, GOLD, Color(GOLD, 0.5))
		plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		plus_btn.add_child(plus_lbl)
		
		if plus_action.is_valid():
			plus_btn.pressed.connect(plus_action)
			
		hc.add_child(plus_btn)
		
	return cap

static func make_header(title: String, show_back: bool = true, show_coins: bool = true, back_callable: Callable = Callable()) -> HBoxContainer:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", SP_MD)
	
	if show_back:
		var back = Button.new()
		back.name = "BackBtn"
		back.custom_minimum_size = Vector2(44, 44)
		back.add_theme_stylebox_override("normal", btn_tertiary())
		back.add_theme_stylebox_override("hover", btn_secondary_hover(CYAN))
		
		var icon = UIIcon.new(UIIcon.Type.BACK, WHITE, 20)
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.add_child(center)
		center.add_child(icon)
		
		if back_callable.is_valid():
			back.pressed.connect(back_callable)
		header.add_child(back)
	
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.label_settings = ls_title()
	header.add_child(title_lbl)
	
	if show_coins:
		var coins_cap = make_coin_capsule(0)
		coins_cap.name = "HeaderCoinCap"
		header.add_child(coins_cap)
	elif show_back:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(44, 44)
		header.add_child(spacer)
	
	return header

static func make_rank_emblem(rank: Dictionary, size: int = 100) -> Control:
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(size, size)
	
	if rank.has("texture"):
		var tex_rect = TextureRect.new()
		tex_rect.texture = load(rank.texture)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(size, size)
		center.add_child(tex_rect)
		return center
	
	var orb_bg = Panel.new()
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = rank.color.darkened(0.6)
	sb_bg.border_color = rank.color.lightened(0.2)
	sb_bg.set_border_width_all(int(size * 0.05))
	sb_bg.set_corner_radius_all(size / 2)
	sb_bg.shadow_color = Color(rank.color, 0.5)
	sb_bg.shadow_size = int(size * 0.3)
	orb_bg.add_theme_stylebox_override("panel", sb_bg)
	orb_bg.custom_minimum_size = Vector2(size, size)
	center.add_child(orb_bg)
	
	var orb_glow = Panel.new()
	var sb_glow = StyleBoxFlat.new()
	sb_glow.bg_color = rank.color
	sb_glow.bg_color.a = 0.2
	sb_glow.set_corner_radius_all(size / 2)
	orb_glow.add_theme_stylebox_override("panel", sb_glow)
	orb_glow.custom_minimum_size = Vector2(size * 0.8, size * 0.8)
	center.add_child(orb_glow)
	
	# Initial
	var lbl = Label.new()
	lbl.text = rank.name.substr(0, 1)
	lbl.label_settings = ls_title_font(int(size * 0.4), rank.color.lightened(0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.add_child(lbl)
	
	return center

static func make_progress_bar(progress: float, total: float, is_purple: bool = true) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	
	var nums = Label.new()
	nums.text = "%d / %d" % [int(progress), int(total)]
	nums.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nums.label_settings = ls_number(32)
	container.add_child(nums)
	
	var track = PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 16)
	var track_sb = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.15, 0.05, 0.2) if is_purple else SURFACE_LT
	track_sb.set_corner_radius_all(8)
	track_sb.shadow_color = Color(0, 0, 0, 0.8)
	track_sb.shadow_size = 4
	track.add_theme_stylebox_override("panel", track_sb)
	container.add_child(track)
	
	var fill_ratio = clampf(progress / max(total, 1.0), 0.0, 1.0)
	if fill_ratio > 0.0:
		var fill = PanelContainer.new()
		fill.anchor_right = fill_ratio
		fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		fill.anchor_right = fill_ratio
		fill.offset_right = 0
		var fill_sb = StyleBoxFlat.new()
		fill_sb.bg_color = CYAN
		# We would use a GradientTexture1D for true gradients, but solid is fine for now
		if is_purple:
			fill_sb.bg_color = MAGENTA.lerp(CYAN, 0.5)
		fill_sb.set_corner_radius_all(8)
		fill_sb.shadow_color = Color(fill_sb.bg_color, 0.5)
		fill_sb.shadow_size = 8
		fill.add_theme_stylebox_override("panel", fill_sb)
		track.add_child(fill)
	
	return container
