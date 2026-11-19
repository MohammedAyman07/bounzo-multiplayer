extends Node

# =====================================================
# SAVE MANAGER
# Handles persistent offline storage in user://
# Registered as Autoload "SaveManager" in project.godot.
# =====================================================

const SAVE_PATH: String = "user://save_data.json"

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_create_default_save()
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_create_default_save()
		return
		
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(content)
	
	if err == OK and typeof(json.data) == TYPE_DICTIONARY:
		data = json.data
		_validate_and_migrate_save()
	else:
		push_warning("Save file corrupted. Recovering with default values.")
		_create_default_save()


func save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("Failed to write save file.")


func _create_default_save() -> void:
	data = {
		"version": 5,
		"highest_phase_reached": 1,
		"coins": 0,
		"best_score": 0,
		"best_chain": 0,
		"selected_ball": "basic",
		"selected_trail": "basic",
		"unlocked_balls": ["basic"],
		"unlocked_trails": ["basic"],
		"daily_date": "",
		"daily_challenge_id": "",
		"daily_challenge_progress": 0,
		"daily_challenge_completed": false,
		"daily_challenge_claimed": false,
		"mission_date": "",
		"missions": [],
		"music_enabled": true,
		"music_volume": 0.70,
		"sfx_enabled": true,
		"sfx_volume": 1.00,
		"vibration_enabled": true,
		"runs_since_interstitial": 0,
		"ad_free_coin_time": 0,
		"rival_date": "",
		"rival_base_score": 0,
		"challenge_completion_status": {},
		"challenge_best_scores": {},
		"unlocked_ranks": ["bronze"],
		"rank_stars": {},
		"free_coins_progress": {"50": 0, "100": 0, "200": 0, "500": 0, "1000": 0},
		"free_coins_date": "",
		"free_coins_claimed": [],
		"first_time_tutorial_completed": false
	}
	save_data()


func _validate_and_migrate_save() -> void:
	# Ensure all required keys exist, filling defaults if missing
	var defaults = {
		"version": 5,
		"highest_phase_reached": 1,
		"coins": 0,
		"best_score": 0,
		"best_chain": 0,
		"selected_ball": "basic",
		"selected_trail": "basic",
		"unlocked_balls": ["basic"],
		"unlocked_trails": ["basic"],
		"daily_date": "",
		"daily_challenge_id": "",
		"daily_challenge_progress": 0,
		"daily_challenge_completed": false,
		"daily_challenge_claimed": false,
		"mission_date": "",
		"missions": [],
		"music_enabled": true,
		"music_volume": 0.70,
		"sfx_enabled": true,
		"sfx_volume": 1.00,
		"vibration_enabled": true,
		"runs_since_interstitial": 0,
		"ad_free_coin_time": 0,
		"rival_date": "",
		"rival_base_score": 0,
		"challenge_completion_status": {},
		"challenge_best_scores": {},
		"unlocked_ranks": ["bronze"],
		"rank_stars": {},
		"free_coins_progress": {"50": 0, "100": 0, "200": 0, "500": 0, "1000": 0},
		"free_coins_date": "",
		"free_coins_claimed": [],
		"first_time_tutorial_completed": false
	}
	
	var dirty = false
	
	# Migrate from version 2 to 3
	if data.has("version") and typeof(data["version"]) in [TYPE_INT, TYPE_FLOAT] and data["version"] < 3:
		data["version"] = 3
		dirty = true
		
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]
			dirty = true
		elif typeof(data[key]) != typeof(defaults[key]):
			if typeof(defaults[key]) == TYPE_INT and typeof(data[key]) == TYPE_FLOAT:
				data[key] = int(data[key])
			else:
				data[key] = defaults[key]
				dirty = true
			
	# SECURITY HARDENING: Explicitly validate bounds and contents
	
	# COINS
	if typeof(data["coins"]) not in [TYPE_INT, TYPE_FLOAT] or data["coins"] < 0 or fmod(data["coins"], 1.0) != 0.0:
		data["coins"] = 0
		dirty = true
	else:
		var clamped = clampi(int(data["coins"]), 0, 999999999)
		if data["coins"] != clamped:
			data["coins"] = clamped
			dirty = true
			
	# RANK VALIDATION
	var valid_ranks = ["bronze", "silver", "gold", "platinum", "diamond", "master", "grandmaster"]
	var u_ranks = data.get("unlocked_ranks", [])
	if typeof(u_ranks) != TYPE_ARRAY:
		u_ranks = ["bronze"]
		data["unlocked_ranks"] = u_ranks
		dirty = true
	else:
		var clean_ranks = []
		for r in u_ranks:
			if typeof(r) == TYPE_STRING and valid_ranks.has(r) and not clean_ranks.has(r):
				clean_ranks.append(r)
		if clean_ranks.size() == 0 or not clean_ranks.has("bronze"):
			if not clean_ranks.has("bronze"): clean_ranks.push_front("bronze")
		if clean_ranks.size() != u_ranks.size():
			data["unlocked_ranks"] = clean_ranks
			dirty = true
			
	# RANK STARS VALIDATION
	var r_stars = data.get("rank_stars", {})
	if typeof(r_stars) != TYPE_DICTIONARY:
		data["rank_stars"] = {}
		dirty = true
	else:
		for k in r_stars.keys():
			if typeof(k) != TYPE_STRING or not valid_ranks.has(k):
				r_stars.erase(k)
				dirty = true
			else:
				var v = r_stars[k]
				if typeof(v) not in [TYPE_INT, TYPE_FLOAT] or v < 0 or fmod(v, 1.0) != 0.0:
					r_stars[k] = 0
					dirty = true
				else:
					r_stars[k] = clampi(int(v), 0, 9999)
					
	# CHALLENGE BEST SCORES VALIDATION
	var b_scores = data.get("challenge_best_scores", {})
	if typeof(b_scores) != TYPE_DICTIONARY:
		data["challenge_best_scores"] = {}
		dirty = true
	else:
		for k in b_scores.keys():
			if typeof(k) != TYPE_STRING:
				b_scores.erase(k)
				dirty = true
			else:
				var v = b_scores[k]
				if typeof(v) not in [TYPE_INT, TYPE_FLOAT] or v < 0 or fmod(v, 1.0) != 0.0:
					b_scores[k] = 0
					dirty = true
				else:
					b_scores[k] = clampi(int(v), 0, 999999999)
			
	if dirty:
		save_data()
