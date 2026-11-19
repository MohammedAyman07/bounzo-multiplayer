extends Node

# =====================================================
# DIFFICULTY MANAGER
# Returns per-stage generation parameters based on
# the current score (baseline) and chain (modifier).
# =====================================================

# Baseline parameters based on SCORE
const SCORE_BANDS: Array = [
	# 0-499
	{"name": "LEARNING",    "score": 0,     "w_min": 220.0, "w_max": 260.0, "h_off": 120.0, "v_min": 100.0, "v_max": 120.0, "speed": 1.00},
	# 500-999
	{"name": "PREPARATION", "score": 500,   "w_min": 190.0, "w_max": 230.0, "h_off": 150.0, "v_min": 110.0, "v_max": 130.0, "speed": 1.05},
	# 1000-1499
	{"name": "CHALLENGE",   "score": 1000,  "w_min": 150.0, "w_max": 180.0, "h_off": 180.0, "v_min": 120.0, "v_max": 140.0, "speed": 1.20},
	# 1500-2499
	{"name": "HARD",        "score": 1500,  "w_min": 130.0, "w_max": 160.0, "h_off": 190.0, "v_min": 125.0, "v_max": 145.0, "speed": 1.30},
	# 2500-4999
	{"name": "VERY HARD",   "score": 2500,  "w_min": 110.0, "w_max": 140.0, "h_off": 200.0, "v_min": 130.0, "v_max": 150.0, "speed": 1.35},
	# 5000-9999
	{"name": "EXPERT",      "score": 5000,  "w_min": 90.0,  "w_max": 120.0, "h_off": 210.0, "v_min": 135.0, "v_max": 155.0, "speed": 1.40},
	# 10000-19999
	{"name": "MASTER",      "score": 10000, "w_min": 85.0,  "w_max": 110.0, "h_off": 215.0, "v_min": 140.0, "v_max": 160.0, "speed": 1.45},
	# 20000+
	{"name": "CHAOS",       "score": 20000, "w_min": 80.0,  "w_max": 100.0, "h_off": 220.0, "v_min": 145.0, "v_max": 165.0, "speed": 1.50},
]

# Minimum absolute platform width regardless of difficulty
const ABSOLUTE_MIN_WIDTH: float = 75.0

# Screen margins kept constant
const SCREEN_MARGIN: float = 30.0

var _recent_landings: Array = []

func record_landing(grade: int) -> void:
	_recent_landings.append(grade)
	if _recent_landings.size() > 10:
		_recent_landings.pop_front()

func _get_performance_multiplier() -> Dictionary:
	var mults = { "width": 1.0, "speed": 1.0, "hazard": 1.0, "warning": 1.0 }
	
	if _recent_landings.size() < 5:
		return mults # Not enough data yet
		
	var struggling = 0
	var skilled = 0
	
	for g in _recent_landings:
		if g == 0 or g == 1: # PERFECT, GOOD
			skilled += 1
		elif g == 2 or g == 3 or g == 4: # NORMAL, NEAR, MISS
			struggling += 1
			
	if struggling >= 7: # Player is struggling
		mults["width"] = 1.10
		mults["speed"] = 0.95
		mults["hazard"] = 0.95
		mults["warning"] = 1.05
	elif skilled >= 7: # Player is skilled
		mults["width"] = 0.95
		mults["speed"] = 1.05
		mults["hazard"] = 1.05
		mults["warning"] = 0.95
		
	return mults

func get_stage_by_score(score: int) -> Dictionary:
	var effective_score = score
	
	if ChallengeManager.is_active():
		var chal = ChallengeManager.get_active_challenge()
		if not chal.is_empty():
			if chal.difficulty == "HARD": effective_score = max(effective_score, 1500)
			elif chal.difficulty == "VERY HARD": effective_score = max(effective_score, 2500)
			elif chal.difficulty == "EXPERT": effective_score = max(effective_score, 5000)
			elif chal.difficulty == "MASTER": effective_score = max(effective_score, 10000)
			elif chal.difficulty == "CHAOS": effective_score = max(effective_score, 20000)
			
	for i in range(SCORE_BANDS.size() - 1, -1, -1):
		if effective_score >= SCORE_BANDS[i]["score"]:
			return SCORE_BANDS[i]
	return SCORE_BANDS[0]

func get_chain_modifier(chain: int) -> float:
	if chain >= 20: return 1.15
	if chain >= 11: return 1.10
	if chain >= 6:  return 1.05
	return 1.00

func get_params(score: int, chain: int) -> Dictionary:
	var base_params = get_stage_by_score(score).duplicate()
	var perf = _get_performance_multiplier()
	var chain_mult = get_chain_modifier(chain)
	
	var wpm = get_tree().root.get_node_or_null("WorldPhaseManager")
	if wpm:
		var config = wpm.current_phase_config
		if not config.is_empty():
			# Note: w_min and w_max are inversely scaled by chain_mult 
			# (higher chain = harder = smaller width)
			var width_chain_mult = 1.0 / chain_mult
			
			base_params["w_min"] *= config.get("platform_width_mult", 1.0) * perf["width"] * width_chain_mult
			base_params["w_max"] *= config.get("platform_width_mult", 1.0) * perf["width"] * width_chain_mult
			
			base_params["w_min"] = max(base_params["w_min"], ABSOLUTE_MIN_WIDTH)
			base_params["w_max"] = max(base_params["w_max"], ABSOLUTE_MIN_WIDTH)
			
			base_params["speed"] *= config.get("platform_speed_mult", 1.0) * perf["speed"] * chain_mult
			
			base_params["v_min"] *= config.get("difficulty_mult", 1.0) * chain_mult
			base_params["v_max"] *= config.get("difficulty_mult", 1.0) * chain_mult
			
			base_params["h_off"] *= config.get("difficulty_mult", 1.0) * chain_mult
			
	base_params["hazard_mult"] = perf["hazard"]
	base_params["warning_mult"] = perf["warning"]
	
	return base_params
