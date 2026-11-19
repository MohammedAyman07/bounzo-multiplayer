extends Node

# =====================================================
# AD MANAGER (REAL ADMOB INTEGRATION)
# Centralized AdMob integration logic.
# =====================================================

const AD_TEST_MODE: bool = false
const AD_MOCK_MODE: bool = false  # false = real AdMob on device

const INTERSTITIAL_RUN_FREQUENCY: int = 4

signal rewarded_ad_completed(reward_id: String)
signal rewarded_ad_failed(reward_id: String)
signal rewarded_ad_closed()
signal interstitial_closed()

var _reward_pending_id: String = ""
var _reward_earned: bool = false
var _is_ad_showing: bool = false
var _runs_since_interstitial: int = 0
var _admob_initialized: bool = false
var _was_paused_before_ad: bool = false
var _banner_requested: bool = false

var _mock_canvas: CanvasLayer = null

func _ready() -> void:
	if SaveManager.data.has("runs_since_interstitial"):
		_runs_since_interstitial = SaveManager.data["runs_since_interstitial"]
	if AD_MOCK_MODE:
		_setup_mock_ui()
	else:
		if Engine.has_singleton("AdmobPlugin"):
			_setup_admob()
		else:
			print("AdManager: AdmobPlugin singleton not found — running without ads.")
			_admob_initialized = false

# =====================================================
# PUBLIC API
# =====================================================

func show_rewarded(reward_id: String) -> void:
	if _is_ad_showing:
		return
	
	_reward_pending_id = reward_id
	
	if AD_MOCK_MODE:
		_is_ad_showing = true
		_pause_game()
		_show_mock_ui("REWARDED AD", true)
	else:
		if not _admob_initialized or not MobileAds.is_rewarded_ad_loaded():
			print("AdManager: Rewarded ad unavailable.")
			# CRITICAL FAILURE RULE: Do NOT simulate reward, emit failure
			var r_id = _reward_pending_id
			_reward_pending_id = ""
			rewarded_ad_failed.emit(r_id)
			if _admob_initialized:
				MobileAds.load_rewarded_ad()
			return
			
		_is_ad_showing = true
		_pause_game()
		MobileAds.show_rewarded_ad()

func show_interstitial() -> void:
	if _is_ad_showing:
		return
		
	if AD_MOCK_MODE:
		_is_ad_showing = true
		_pause_game()
		_show_mock_ui("INTERSTITIAL AD", false)
	else:
		if not _admob_initialized or not MobileAds.is_interstitial_ad_loaded():
			print("AdManager: Interstitial ad unavailable. Continuing...")
			# Interstitial failure: Continue normally
			_on_interstitial_closed_internal()
			if _admob_initialized:
				MobileAds.load_interstitial_ad()
			return
			
		_is_ad_showing = true
		_pause_game()
		MobileAds.show_interstitial_ad()

func show_banner() -> void:
	_banner_requested = true
	print("--- BANNER DIAGNOSTIC: UI REQUESTED SHOW_BANNER ---")
	if AD_MOCK_MODE or not _admob_initialized:
		print("--- BANNER DIAGNOSTIC: IGNORING SHOW (Mock or Not Initialized) ---")
		return
	MobileAds.show_banner_ad()
	print("--- BANNER DIAGNOSTIC: show_banner_ad() CALLED ---")

func hide_banner() -> void:
	_banner_requested = false
	if AD_MOCK_MODE or not _admob_initialized:
		return
	MobileAds.hide_banner_ad()

func record_run_completed() -> void:
	_runs_since_interstitial += 1
	SaveManager.data["runs_since_interstitial"] = _runs_since_interstitial
	SaveManager.save_data()

func can_show_rewarded() -> bool:
	if AD_MOCK_MODE:
		return true
	if not _admob_initialized:
		return false
	return MobileAds.is_rewarded_ad_loaded()

func should_show_interstitial() -> bool:
	return _runs_since_interstitial >= INTERSTITIAL_RUN_FREQUENCY

# =====================================================
# REAL ADMOB INTEGRATION
# =====================================================

func _setup_admob() -> void:
	# is_real = true uses the real ad unit IDs provided in Admob.gd.
	# IMPORTANT: Never click your own real ads while testing!
	MobileAds.is_real = true
	
	# Ensure the AdMob node always processes so Android callbacks are not blocked while the game is paused
	MobileAds.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set banner to bottom
	MobileAds.banner_position = 1 # 1 = BOTTOM in LoadAdRequest.AdPosition
	
	# === HARDCODED REAL ADMOB IDS FOR EARNING ===
	MobileAds.android_real_application_id = "ca-app-pub-9798621020559640~5936123429"
	MobileAds.android_real_banner_id = "ca-app-pub-9798621020559640/4530854053"
	MobileAds.android_real_interstitial_id = "ca-app-pub-9798621020559640/3217772385"
	MobileAds.android_real_rewarded_id = "ca-app-pub-9798621020559640/5349111700"
	# ============================================

	
	# Connect lifecycle signals BEFORE calling initialize()
	if not MobileAds.initialization_completed.is_connected(_on_admob_initialized):
		MobileAds.initialization_completed.connect(_on_admob_initialized)
	
	if not MobileAds.rewarded_ad_user_earned_reward.is_connected(_on_admob_rewarded_earned):
		MobileAds.rewarded_ad_user_earned_reward.connect(_on_admob_rewarded_earned)
	
	if not MobileAds.rewarded_ad_dismissed_full_screen_content.is_connected(_on_admob_rewarded_closed):
		MobileAds.rewarded_ad_dismissed_full_screen_content.connect(_on_admob_rewarded_closed)
	
	if not MobileAds.rewarded_ad_failed_to_show_full_screen_content.is_connected(_on_admob_rewarded_failed_to_show):
		MobileAds.rewarded_ad_failed_to_show_full_screen_content.connect(_on_admob_rewarded_failed_to_show)
	
	if not MobileAds.interstitial_ad_dismissed_full_screen_content.is_connected(_on_admob_interstitial_closed):
		MobileAds.interstitial_ad_dismissed_full_screen_content.connect(_on_admob_interstitial_closed)
	
	if not MobileAds.interstitial_ad_failed_to_show_full_screen_content.is_connected(_on_admob_interstitial_failed_to_show):
		MobileAds.interstitial_ad_failed_to_show_full_screen_content.connect(_on_admob_interstitial_failed_to_show)
	
	if not MobileAds.interstitial_ad_failed_to_load.is_connected(_on_interstitial_failed_to_load):
		MobileAds.interstitial_ad_failed_to_load.connect(_on_interstitial_failed_to_load)
	if not MobileAds.banner_ad_failed_to_load.is_connected(_on_banner_failed_to_load):
		MobileAds.banner_ad_failed_to_load.connect(_on_banner_failed_to_load)
	if not MobileAds.banner_ad_loaded.is_connected(_on_banner_loaded):
		MobileAds.banner_ad_loaded.connect(_on_banner_loaded)
	if not MobileAds.rewarded_ad_loaded.is_connected(_on_rewarded_loaded):
		MobileAds.rewarded_ad_loaded.connect(_on_rewarded_loaded)
	if not MobileAds.rewarded_ad_failed_to_load.is_connected(_on_rewarded_failed_to_load):
		MobileAds.rewarded_ad_failed_to_load.connect(_on_rewarded_failed_to_load)
		
	# Initialize AdMob — plugin picks test IDs automatically when is_real = false
	MobileAds.initialize()

func _on_admob_initialized(status_data) -> void:
	_admob_initialized = true
	print("AdManager: AdMob Initialized.")
	MobileAds.load_rewarded_ad()
	MobileAds.load_interstitial_ad()
	MobileAds.load_banner_ad() # Preload banner
	if _banner_requested:
		MobileAds.show_banner_ad()

func _on_interstitial_failed_to_load(ad_info, error_data) -> void:
	print("AdManager: Interstitial failed to load. Retrying in 5 seconds...")
	await get_tree().create_timer(5.0).timeout
	if _admob_initialized:
		MobileAds.load_interstitial_ad()

func _on_banner_failed_to_load(ad_info, error_data) -> void:
	print("--- BANNER DIAGNOSTIC: LOAD FAILED ---")
	print("Error Data: ", error_data)
	print("Retrying in 5 seconds...")
	await get_tree().create_timer(5.0).timeout
	if _admob_initialized:
		MobileAds.load_banner_ad()

func _on_banner_loaded(ad_info, response_info) -> void:
	print("--- BANNER DIAGNOSTIC: LOAD SUCCESS ---")
	print("Ad Info: ", ad_info)
	print("Response Info: ", response_info)
	if _banner_requested:
		print("--- BANNER DIAGNOSTIC: ATTEMPTING TO SHOW BANNER ---")
		MobileAds.show_banner_ad()
	else:
		print("--- BANNER DIAGNOSTIC: BANNER NOT REQUESTED YET ---")

func _on_rewarded_loaded(ad_info, response_info) -> void:
	print("AdManager: Rewarded ad loaded successfully.")

func _on_rewarded_failed_to_load(ad_info, error_data) -> void:
	print("AdManager: Rewarded ad failed to load. Retrying in 5 seconds...")
	await get_tree().create_timer(5.0).timeout
	if _admob_initialized:
		MobileAds.load_rewarded_ad()

var _reward_earned_this_session: bool = false
var _reward_earned_id: String = ""

func _on_admob_rewarded_earned(ad_info, reward_data) -> void:
	if _is_ad_showing:
		_reward_earned_this_session = true
		_reward_earned_id = _reward_pending_id
		_reward_pending_id = ""
	else:
		var r_id = _reward_pending_id
		if r_id == "": r_id = _reward_earned_id
		_reward_pending_id = ""
		_reward_earned_id = ""
		if r_id != "":
			rewarded_ad_completed.emit(r_id)

func _on_admob_rewarded_closed(ad_info) -> void:
	_resume_game()
	_is_ad_showing = false
	
	if _reward_earned_this_session:
		_reward_earned_this_session = false
		var r_id = _reward_earned_id
		_reward_earned_id = ""
		rewarded_ad_completed.emit(r_id)
	else:
		_check_failed_deferred(_reward_pending_id)
		
	rewarded_ad_closed.emit()
	MobileAds.load_rewarded_ad()

func _check_failed_deferred(r_id: String) -> void:
	if r_id == "": return
	await get_tree().create_timer(1.0).timeout
	if _reward_pending_id == r_id:
		_reward_pending_id = ""
		rewarded_ad_failed.emit(r_id)


func _on_admob_rewarded_failed_to_show(ad_info, error_data) -> void:
	_resume_game()
	_is_ad_showing = false
	if _reward_pending_id != "":
		var r_id = _reward_pending_id
		_reward_pending_id = ""
		rewarded_ad_failed.emit(r_id)
	rewarded_ad_closed.emit()
	MobileAds.load_rewarded_ad()

func _on_admob_interstitial_closed(ad_info) -> void:
	_on_interstitial_closed_internal()
	MobileAds.load_interstitial_ad()

func _on_admob_interstitial_failed_to_show(ad_info, error_data) -> void:
	_on_interstitial_closed_internal()
	MobileAds.load_interstitial_ad()

# =====================================================
# INTERNAL
# =====================================================

func _on_interstitial_closed_internal() -> void:
	_resume_game()
	_is_ad_showing = false
	_runs_since_interstitial = 0
	SaveManager.data["runs_since_interstitial"] = 0
	SaveManager.save_data()
	interstitial_closed.emit()

func _pause_game() -> void:
	_was_paused_before_ad = get_tree().paused
	get_tree().paused = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)

func _resume_game() -> void:
	get_tree().paused = _was_paused_before_ad
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

# =====================================================
# MOCK UI IMPLEMENTATION
# =====================================================

func _setup_mock_ui() -> void:
	_mock_canvas = CanvasLayer.new()
	_mock_canvas.layer = 120
	_mock_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_mock_canvas)
	
	# Full-screen dark background
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.04, 0.02, 0.10, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_mock_canvas.add_child(bg)
	
	# Center container — anchored full rect, then center children
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mock_canvas.add_child(center)
	
	var vb = VBoxContainer.new()
	vb.name = "VBox"
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	vb.custom_minimum_size = Vector2(300, 0)
	center.add_child(vb)
	
	# Ad icon label
	var icon_lbl = Label.new()
	icon_lbl.text = "📺"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 64)
	vb.add_child(icon_lbl)
	
	var title = Label.new()
	title.name = "Title"
	title.text = "TEST AD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vb.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "(Mock — Editor Only)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.7, 0.7, 0.7, 1.0)
	vb.add_child(subtitle)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)
	
	var btn_complete = Button.new()
	btn_complete.name = "CompleteBtn"
	btn_complete.text = "✔  COMPLETE AD (Get Reward)"
	btn_complete.custom_minimum_size = Vector2(280, 60)
	btn_complete.pressed.connect(func():
		if _reward_pending_id != "":
			var r_id = _reward_pending_id
			_reward_pending_id = ""
			rewarded_ad_completed.emit(r_id)
			_resume_game()
			_is_ad_showing = false
			rewarded_ad_closed.emit()
		else:
			_on_interstitial_closed_internal()
	)
	vb.add_child(btn_complete)
	
	var btn_close = Button.new()
	btn_close.name = "CloseBtn"
	btn_close.text = "✖  CLOSE AD EARLY (No Reward)"
	btn_close.custom_minimum_size = Vector2(280, 60)
	btn_close.pressed.connect(func():
		if _reward_pending_id != "":
			var r_id = _reward_pending_id
			_reward_pending_id = ""
			_resume_game()
			_is_ad_showing = false
			rewarded_ad_failed.emit(r_id)
			rewarded_ad_closed.emit()
		else:
			_on_interstitial_closed_internal()
	)
	vb.add_child(btn_close)
	
	_mock_canvas.hide()

func _show_mock_ui(ad_title: String, is_rewarded: bool) -> void:
	if not _mock_canvas: return
	var vb = _mock_canvas.get_node_or_null("VBox")
	if not vb:
		# Try nested path
		vb = _mock_canvas.get_node_or_null("CenterContainer/VBox")
	if vb:
		var title_node = vb.get_node_or_null("Title")
		if title_node:
			title_node.text = ad_title
		var complete_btn = vb.get_node_or_null("CompleteBtn")
		if complete_btn:
			complete_btn.visible = is_rewarded
	_mock_canvas.show()
	
	if not _mock_canvas.get_meta("hooked", false):
		rewarded_ad_closed.connect(func(): _mock_canvas.hide())
		interstitial_closed.connect(func(): _mock_canvas.hide())
		_mock_canvas.set_meta("hooked", true)
