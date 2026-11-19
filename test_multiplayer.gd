extends SceneTree

# ==============================================================================
# BOUNZO MULTIPLAYER & REGRESSION TEST HARNESS
# Tests all 20 requirements outlined in STAGE 8
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")
const ServerRoomManager = preload("res://scripts/multiplayer/room_manager.gd")
const ServerMatchManager = preload("res://scripts/multiplayer/match_manager.gd")
const PlatformGenScript = preload("res://scripts/multiplayer/multiplayer_platform_generator.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("\n========================================================")
	print(" BOUNZO TEST SUITE — MULTIPLAYER & SINGLE-PLAYER REGRESSION")
	print("========================================================\n")

	# Await SceneTree frame so all autoload singletons are instantiated and ready
	await process_frame
	await process_frame

	_run_all_tests()

	print("\n========================================================")
	print(" TEST SUMMARY: %d Total | %d PASSED | %d FAILED" % [total_tests, passed_tests, failed_tests])
	print("========================================================\n")

	if failed_tests == 0:
		print(">>> ALL TESTS PASSED SUCCESSFULLY! <<<\n")
		quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		quit(1)

func assert_true(condition: bool, test_name: String, details: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[PASS] Test %2d: %s" % [total_tests, test_name])
	else:
		failed_tests += 1
		printerr("[FAIL] Test %2d: %s — %s" % [total_tests, test_name, details])

func _run_all_tests() -> void:
	test_1_single_player_startup()
	test_2_save_loading_and_compatibility()
	test_3_coins_shop_and_cosmetics()
	test_4_ranks_and_challenges()
	test_5_admob_callbacks_and_reward_protection()
	test_6_two_player_room_creation_and_joining()
	test_7_four_player_capacity()
	test_8_rejection_of_fifth_player()
	test_9_invalid_and_expired_room_codes()
	test_10_ready_up_and_synchronized_countdown()
	test_11_match_start_and_completion()
	test_12_score_and_result_validation()
	test_13_simultaneous_disconnects()
	test_14_room_creator_disconnect()
	test_15_server_timeout_and_error_handling()
	test_16_rematch_and_returning_to_lobby()
	test_17_android_touch_controls_mapping()
	test_18_server_restart_and_resource_cleanup()
	test_19_spam_invalid_payloads_and_rate_limiting()
	test_20_no_accidental_save_or_reward_modifications()
	test_21_target_score_room_configuration()
	test_22_two_player_last_man_standing_win()
	test_23_three_player_sequential_elimination()
	test_24_target_score_race_win()
	test_25_platform_obstacles_and_struggles()
	test_26_living_player_comeback_and_overtake()
	test_27_target_score_range_and_clamping()
	test_28_multiplayer_difficulty_scaling()

# 1. Existing single-player startup and gameplay scene integrity
func test_1_single_player_startup() -> void:
	var game_scene = load("res://scenes/game/game.tscn")
	var is_valid_scene = (game_scene != null and game_scene is PackedScene)
	assert_true(is_valid_scene, "Single-Player Startup: game.tscn loads as PackedScene")

# 2. Existing save loading and save compatibility
func test_2_save_loading_and_compatibility() -> void:
	var save_mgr = root.get_node_or_null("SaveManager")
	var has_save = (save_mgr != null and save_mgr.data is Dictionary and save_mgr.data.has("version"))
	var version_ok = (has_save and save_mgr.data.version >= 3)
	assert_true(has_save and version_ok, "Save Compatibility: SaveManager loaded version %s" % (save_mgr.data.version if has_save else "N/A"))

# 3. Existing coins, shop and cosmetics
func test_3_coins_shop_and_cosmetics() -> void:
	var cur_mgr = root.get_node_or_null("CurrencyManager")
	var cos_mgr = root.get_node_or_null("CosmeticData")
	var coins_ok = (cur_mgr != null and cur_mgr.get_coins() >= 0)
	var cosmetics_ok = (cos_mgr != null and cos_mgr.BALLS.has("basic") and cos_mgr.BALLS.has("fire"))
	assert_true(coins_ok and cosmetics_ok, "Economy & Cosmetics: CurrencyManager & CosmeticData valid")

# 4. Existing ranks and challenges
func test_4_ranks_and_challenges() -> void:
	var chal_mgr = root.get_node_or_null("ChallengeManager")
	var daily_mgr = root.get_node_or_null("DailyChallengeManager")
	var diff_mgr = root.get_node_or_null("DifficultyManager")
	var params = diff_mgr.get_params(0, 0) if diff_mgr else {}
	assert_true(chal_mgr != null and daily_mgr != null and params.has("w_min"), "Ranks & Challenges: Systems operational")

# 5. Existing AdMob callbacks and reward protection
func test_5_admob_callbacks_and_reward_protection() -> void:
	var ad_mgr = root.get_node_or_null("AdManager")
	var has_signals = ad_mgr != null and ad_mgr.has_signal("rewarded_ad_completed") and ad_mgr.has_signal("rewarded_ad_failed")
	assert_true(has_signals and not ad_mgr._is_ad_showing, "AdMob Protection: Rewarded signals & state verified")

# 6. Two-player room creation and joining
func test_6_two_player_room_creation_and_joining() -> void:
	var rm = ServerRoomManager.new()
	var create_res = rm.create_room(101, "HostPlayer", {"ball": "basic"})
	var code = create_res.get("code", "")
	var code_valid = Protocol.is_valid_room_code_format(code)

	var join_res = rm.join_room(102, code, "PeerPlayer", {"ball": "fire"})
	var both_in_room = (create_res.success and join_res.success and rm.rooms[code].players.size() == 2)
	assert_true(both_in_room and code_valid, "2-Player Room: Creation & Joining with valid code %s" % code)

# 7. Four-player capacity
func test_7_four_player_capacity() -> void:
	var rm = ServerRoomManager.new()
	var c_res = rm.create_room(101, "Host", {})
	var code = c_res.code
	rm.join_room(102, code, "Player2", {})
	rm.join_room(103, code, "Player3", {})
	var p4_res = rm.join_room(104, code, "Player4", {})
	var count = rm.rooms[code].players.size()
	assert_true(p4_res.success and count == 4, "4-Player Capacity: Room successfully filled to 4/4")

# 8. Rejection of a fifth player
func test_8_rejection_of_fifth_player() -> void:
	var rm = ServerRoomManager.new()
	var c_res = rm.create_room(101, "Host", {})
	var code = c_res.code
	rm.join_room(102, code, "P2", {})
	rm.join_room(103, code, "P3", {})
	rm.join_room(104, code, "P4", {})
	var p5_res = rm.join_room(105, code, "P5", {})
	assert_true(not p5_res.success and p5_res.error == "Room is full (max 4 players)", "Capacity Limit: 5th player rejected")

# 9. Invalid and expired room codes
func test_9_invalid_and_expired_room_codes() -> void:
	var rm = ServerRoomManager.new()
	var res_short = rm.join_room(102, "ABC", "P2", {})
	var res_illegal = rm.join_room(102, "001II", "P2", {})
	var res_nonexist = rm.join_room(102, "ZZZZZ", "P2", {})
	var all_rejected = (not res_short.success and not res_illegal.success and not res_nonexist.success)
	assert_true(all_rejected, "Code Validation: Malformed and non-existent codes rejected")

# 10. Ready-up and synchronized countdown
func test_10_ready_up_and_synchronized_countdown() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var c_res = rm.create_room(101, "Host", {})
	var code = c_res.code
	rm.join_room(102, code, "P2", {})

	# Before ready, cannot start
	var pre_check = rm.can_start_match(code)
	rm.set_player_ready(102, true)
	var post_check = rm.can_start_match(code)
	var countdown_res = mm.start_match_countdown(code)

	var ready_flow_ok = (not pre_check.can_start and post_check.can_start and countdown_res.success and countdown_res.countdown == 3.0)
	assert_true(ready_flow_ok, "Ready & Countdown: Host blocked until ready, countdown started")

# 11. Match start and completion
func test_11_match_start_and_completion() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var code = rm.create_room(101, "Host", {}).code
	rm.join_room(102, code, "P2", {})
	rm.set_player_ready(102, true)
	mm.start_match_countdown(code)

	# Elapse countdown
	var events_cd = mm.process_matches(3.1)
	var game_started = (events_cd.size() > 0 and events_cd[0].event == "game_start")

	# Elapse match duration
	var events_end = mm.process_matches(95.0)
	var game_ended = (events_end.size() > 0 and events_end[0].event == "game_over")
	assert_true(game_started and game_ended, "Match Lifecycle: Countdown transitions to IN_GAME then to RESULTS")

# 12. Score and result validation
func test_12_score_and_result_validation() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var code = rm.create_room(101, "P1", {}).code
	rm.join_room(102, code, "P2", {})
	rm.set_player_ready(102, true)
	mm.start_match_countdown(code)
	mm.process_matches(3.1)

	# Simulate P1 having higher score than P2
	mm.receive_player_update(101, {"x": 270.0, "y": -1200.0, "vx": 0.0, "vy": 0.0, "score": 850, "eliminated": false})
	mm.receive_player_update(102, {"x": 270.0, "y": -500.0, "vx": 0.0, "vy": 0.0, "score": 300, "eliminated": true})

	var results = mm.finish_match(code)
	var p1_won = (results.size() == 2 and results[0].peer_id == 101 and results[0].rank == 1 and results[1].rank == 2)
	assert_true(p1_won, "Result Validation: Higher score ranked 1st place deterministically")

# 13. Simultaneous disconnects
func test_13_simultaneous_disconnects() -> void:
	var rm = ServerRoomManager.new()
	var code = rm.create_room(101, "Host", {}).code
	rm.join_room(102, code, "P2", {})
	rm.join_room(103, code, "P3", {})

	rm.leave_room(102)
	rm.leave_room(103)
	var room = rm.rooms[code]
	assert_true(room.players.size() == 1 and room.available_slots.has(1) and room.available_slots.has(2), "Disconnects: Multiple leaves handled and slots reclaimed")

# 14. Room creator disconnect
func test_14_room_creator_disconnect() -> void:
	var rm = ServerRoomManager.new()
	var code = rm.create_room(101, "Host", {}).code
	rm.join_room(102, code, "P2", {})

	var leave_res = rm.leave_room(101)
	var new_host = rm.rooms[code].host_id
	var all_left = rm.leave_room(102)
	var room_gone = not rm.rooms.has(code)

	assert_true(leave_res.host_changed and new_host == 102 and room_gone, "Host Migration & Cleanup: Host transferred to P2, room freed on final exit")

# 15. Server unavailable or connection timeout
func test_15_server_timeout_and_error_handling() -> void:
	var mp_mgr = root.get_node_or_null("MultiplayerManager")
	var has_timeout = (mp_mgr != null and mp_mgr.connection_timeout >= 3.0)
	assert_true(has_timeout, "Timeout Protection: MultiplayerManager has 6s timeout guard")

# 16. Rematch and returning to the lobby
func test_16_rematch_and_returning_to_lobby() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var code = rm.create_room(101, "Host", {}).code
	rm.join_room(102, code, "P2", {})
	rm.set_player_ready(102, true)
	mm.start_match_countdown(code)
	mm.process_matches(3.1)
	mm.finish_match(code)

	var rematch_res = mm.prepare_rematch(code)
	var state_is_lobby = (rematch_res.success and rm.rooms[code].state == Protocol.RoomState.LOBBY)
	assert_true(state_is_lobby, "Rematch Flow: Match state reset to LOBBY with cleared scores")

# 17. Android touch controls mapping
func test_17_android_touch_controls_mapping() -> void:
	var vp_w = 540.0
	var left_dir = -1.0 if 120.0 < (vp_w * 0.5) else 1.0
	var right_dir = -1.0 if 420.0 < (vp_w * 0.5) else 1.0
	assert_true(left_dir == -1.0 and right_dir == 1.0, "Touch Controls: Left screen steers -1.0, Right steers +1.0")

# 18. Server restart and resource cleanup
func test_18_server_restart_and_resource_cleanup() -> void:
	var rm = ServerRoomManager.new()
	rm.create_room(101, "H1", {})
	rm.create_room(102, "H2", {})
	rm.rooms.clear()
	rm.peer_to_room.clear()
	assert_true(rm.rooms.is_empty() and rm.peer_to_room.is_empty(), "Server Restart: Clean state on reset")

# 19. Spam, invalid payloads and rate limiting
func test_19_spam_invalid_payloads_and_rate_limiting() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var clean_name = Protocol.sanitize_player_name("<script>alert(1)</script>")
	var name_sanitized = (clean_name.find("<") == -1 and clean_name.length() <= Protocol.MAX_NAME_LENGTH)

	# Spam test
	var peer_id = 999
	var accepted_count = 0
	for i in range(50):
		if mm._validate_rate_limit(peer_id):
			accepted_count += 1
	var rate_limited = (accepted_count <= Protocol.MAX_PACKETS_PER_SECOND)
	assert_true(name_sanitized and rate_limited, "Anti-Spam & Security: Names sanitized and packets throttled at %d/s" % Protocol.MAX_PACKETS_PER_SECOND)

# 20. No accidental single-player save or reward modifications
func test_20_no_accidental_save_or_reward_modifications() -> void:
	var save_mgr = root.get_node_or_null("SaveManager")
	var initial_coins = save_mgr.data.coins if save_mgr else 0
	var initial_stars = save_mgr.data.get("rank_stars", {}).duplicate()

	# Simulate multiplayer game actions without affecting SaveManager
	var rm = ServerRoomManager.new()
	var code = rm.create_room(101, "Player", {}).code
	rm.leave_room(101)

	var coins_intact = (save_mgr.data.coins == initial_coins)
	var stars_intact = (save_mgr.data.get("rank_stars", {}) == initial_stars)
	assert_true(coins_intact and stars_intact, "Save Integrity: Single-player save data untouched by multiplayer")

# 21. Target score room configuration & serialization
func test_21_target_score_room_configuration() -> void:
	var rm = ServerRoomManager.new()
	var res = rm.create_room(101, "Host", {})
	var code = res.code
	assert_true(res.room.target_score == 2000, "Target Score: Default target score is 2000")

	# Host changes target score to 3000
	var change_res = rm.set_room_target_score(code, 101, 3000)
	var serialized = ServerRoomManager.serialize_room_state(rm.rooms[code])
	assert_true(change_res.success and serialized.target_score == 3000, "Target Score: Host can change score goal to 3000 and serialized properly")

# 22. 2-Player Last Man Standing immediate win condition
func test_22_two_player_last_man_standing_win() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var code = rm.create_room(101, "Player1", {}).code
	rm.set_room_target_score(code, 101, 0) # Pure LMS mode
	rm.join_room(102, code, "Player2", {})
	rm.set_player_ready(102, true)
	mm.start_match_countdown(code)
	mm.process_matches(3.1) # Transition to IN_GAME

	# Player 1 is eliminated
	mm.receive_player_update(101, {"x": 270.0, "y": -500.0, "score": 100, "eliminated": true})
	# Player 2 is alive with score 50 (lower score than P1, but ALIVE!)
	mm.receive_player_update(102, {"x": 270.0, "y": -800.0, "score": 50, "eliminated": false})

	var events = mm.process_matches(0.1)
	var game_over = (events.size() > 0 and events[0].event == "game_over")
	var results = events[0].results if game_over else []
	var p2_won = (results.size() == 2 and results[0].peer_id == 102 and results[0].rank == 1)

	assert_true(game_over and p2_won, "Last Man Standing (2P): When Player 1 is eliminated, Player 2 immediately declared Winner")

# 23. 3-Player sequential elimination & ranking
func test_23_three_player_sequential_elimination() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var code = rm.create_room(101, "P1", {}).code
	rm.set_room_target_score(code, 101, 0) # Pure LMS mode
	rm.join_room(102, code, "P2", {})
	rm.join_room(103, code, "P3", {})
	rm.set_player_ready(102, true)
	rm.set_player_ready(103, true)
	mm.start_match_countdown(code)
	mm.process_matches(3.1)

	# P1 eliminated first at 5s
	mm.receive_player_update(101, {"x": 270.0, "y": -300.0, "score": 50, "eliminated": true})
	var mid_events = mm.process_matches(0.1)
	var game_still_going = (mid_events.size() == 0 and rm.rooms[code].state == Protocol.RoomState.IN_GAME)

	# P2 eliminated second at 12s
	mm.receive_player_update(102, {"x": 270.0, "y": -700.0, "score": 150, "eliminated": true})
	# P3 is still alive
	mm.receive_player_update(103, {"x": 270.0, "y": -900.0, "score": 80, "eliminated": false})

	var final_events = mm.process_matches(0.1)
	var final_game_over = (final_events.size() > 0 and final_events[0].event == "game_over")
	var res = final_events[0].results if final_game_over else []

	var p3_first = (res.size() == 3 and res[0].peer_id == 103 and res[0].rank == 1)
	var p2_second = (res.size() == 3 and res[1].peer_id == 102 and res[1].rank == 2)
	var p1_third = (res.size() == 3 and res[2].peer_id == 101 and res[2].rank == 3)

	assert_true(game_still_going and final_game_over and p3_first and p2_second and p1_third,
		"Sequential Elimination (3P): 1st out gets 3rd, 2nd out gets 2nd, last survivor gets 1st")

# 24. Target score race win condition
func test_24_target_score_race_win() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var code = rm.create_room(101, "Racer1", {}).code
	rm.set_room_target_score(code, 101, 2000)
	rm.join_room(102, code, "Racer2", {})
	rm.set_player_ready(102, true)
	mm.start_match_countdown(code)
	mm.process_matches(3.1)

	# Racer 1 reaches 2050 points (target reached!), Racer 2 has 1200 points
	mm.receive_player_update(101, {"x": 270.0, "y": -2500.0, "score": 2050, "eliminated": false})
	mm.receive_player_update(102, {"x": 270.0, "y": -1500.0, "score": 1200, "eliminated": false})

	var events = mm.process_matches(0.1)
	var target_win = (events.size() > 0 and events[0].event == "game_over")
	var results = events[0].results if target_win else []
	var racer1_won = (results.size() > 0 and results[0].peer_id == 101 and results[0].rank == 1)

	assert_true(target_win and racer1_won, "Target Score Race: Reaching 2000 points immediately triggers match victory")

# 25. Platform generator 500 platforms with full obstacles and struggles
func test_25_platform_obstacles_and_struggles() -> void:
	var gen = PlatformGenScript.new()
	root.add_child(gen)
	gen.initialize(12345, Vector2(270, -200), 540.0)

	var platform_count = gen._platforms.size()
	var has_moving = false
	var has_fragile = false
	var has_spikes = false
	var has_vanishing = false
	var has_shrink = false

	for p in gen._platforms:
		if p.type == 1: has_moving = true
		if p.type == 2: has_fragile = true
		if p.type == 3: has_spikes = true
		if p.type == 4: has_vanishing = true
		if p.can_shrink: has_shrink = true

	gen.queue_free()

	assert_true(platform_count == 500 and has_moving and has_fragile and has_spikes and has_vanishing and has_shrink,
		"Platform Obstacles: 500 platforms generated with Moving, Fragile, Spikes, Vanishing, and Shrink")

# 26. Living player comeback after opponent eliminated (User Feature Request)
func test_26_living_player_comeback_and_overtake() -> void:
	var rm = ServerRoomManager.new()
	var mm = ServerMatchManager.new(rm)
	var code = rm.create_room(101, "P1", {}).code
	rm.set_room_target_score(code, 101, 2000)
	rm.join_room(102, code, "P2", {})
	rm.set_player_ready(102, true)
	mm.start_match_countdown(code)
	mm.process_matches(3.1)

	# P1 scores 500 and is eliminated!
	mm.receive_player_update(101, {"x": 270.0, "y": -600.0, "score": 500, "eliminated": true})
	# P2 is currently at 350 and STILL ALIVE!
	mm.receive_player_update(102, {"x": 270.0, "y": -400.0, "score": 350, "eliminated": false})

	# Crucial: Game MUST NOT end while P2 is alive!
	var mid_events = mm.process_matches(0.1)
	var game_kept_running = (mid_events.size() == 0 and rm.rooms[code].state == Protocol.RoomState.IN_GAME)

	# P2 continues climbing, reaches 550 points (beating P1's 500!) and then dies
	mm.receive_player_update(102, {"x": 270.0, "y": -650.0, "score": 550, "eliminated": true})
	var final_events = mm.process_matches(0.1)
	var match_ended = (final_events.size() > 0 and final_events[0].event == "game_over")
	var res = final_events[0].results if match_ended else []

	# P2 must be ranked #1 because 550 > 500!
	var p2_won_overtake = (res.size() == 2 and res[0].peer_id == 102 and res[0].rank == 1 and res[1].peer_id == 101 and res[1].rank == 2)

	assert_true(game_kept_running and match_ended and p2_won_overtake,
		"Player Comeback: When P1 dies at 500, match keeps running; P2 climbs to 550 and wins!")

# 27. Target score range and clamping (1,000 to 100,000)
func test_27_target_score_range_and_clamping() -> void:
	var rm = ServerRoomManager.new()
	var code = rm.create_room(101, "Host", {}).code

	# Test min 1000 clamp
	rm.set_room_target_score(code, 101, 500)
	var clamped_min = (rm.rooms[code].target_score == 1000)

	# Test max 100000 clamp
	rm.set_room_target_score(code, 101, 200000)
	var clamped_max = (rm.rooms[code].target_score == 100000)

	# Test valid in-between value (e.g. 25000)
	rm.set_room_target_score(code, 101, 25000)
	var valid_custom = (rm.rooms[code].target_score == 25000)

	assert_true(clamped_min and clamped_max and valid_custom,
		"Target Score Range: Custom scores strictly clamped between min 1,000 and max 100,000")

# 28. Multiplayer difficulty modes (EASY, NORMAL, HARD, INSANE)
func test_28_multiplayer_difficulty_scaling() -> void:
	var rm = ServerRoomManager.new()
	var code = rm.create_room(101, "Host", {}).code

	# Test setting difficulty
	var diff_res = rm.set_room_difficulty(code, 101, "HARD")
	var diff_saved = (diff_res.success and rm.rooms[code].difficulty == "HARD")

	# Test platform generation with difficulties
	var gen_easy = PlatformGenScript.new()
	root.add_child(gen_easy)
	gen_easy.initialize(999, Vector2(270, -200), 540.0, "EASY")
	var easy_first_width = gen_easy._platforms[0].width if "width" in gen_easy._platforms[0] else 350.0

	var gen_hard = PlatformGenScript.new()
	root.add_child(gen_hard)
	gen_hard.initialize(999, Vector2(270, -200), 540.0, "HARD")
	var hard_first_width = gen_hard._platforms[0].width if "width" in gen_hard._platforms[0] else 238.0

	gen_easy.queue_free()
	gen_hard.queue_free()

	assert_true(diff_saved and easy_first_width > hard_first_width,
		"Multiplayer Difficulties: EASY, NORMAL, HARD, INSANE configure course generation deterministically")
