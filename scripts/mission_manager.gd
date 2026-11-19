extends Node

# =====================================================
# MISSION MANAGER
# Generates and tracks a daily set of 3 missions.
# Registered as Autoload "MissionManager" in project.godot.
# =====================================================

signal progress_updated
signal mission_completed(mission_index: int)

const ALL_MISSIONS = [
	{"id": "m1", "type": "runs", "target": 3, "reward": 50, "desc": "Play 3 runs"},
	{"id": "m2", "type": "runs", "target": 5, "reward": 100, "desc": "Play 5 runs"},
	{"id": "m3", "type": "perfect", "target": 10, "reward": 75, "desc": "Get 10 perfect landings"},
	{"id": "m4", "type": "perfect", "target": 25, "reward": 150, "desc": "Get 25 perfect landings"},
	{"id": "m5", "type": "chain", "target": 15, "reward": 100, "desc": "Reach a chain of 15"},
	{"id": "m6", "type": "chain", "target": 25, "reward": 200, "desc": "Reach a chain of 25"},
	{"id": "m7", "type": "coins", "target": 100, "reward": 50, "desc": "Earn 100 coins"},
	{"id": "m8", "type": "score", "target": 1000, "reward": 150, "desc": "Score 1,000 points"},
	{"id": "m9", "type": "landings", "target": 30, "reward": 100, "desc": "Land on 30 platforms"},
	{"id": "m10", "type": "landings", "target": 100, "reward": 250, "desc": "Land on 100 platforms"}
]

# We store current missions as an array of dictionaries:
# [{"id": "m1", "data": {...}, "progress": 0, "completed": false, "claimed": false}]
var current_missions: Array = []

func _ready() -> void:
	reload()
	GameEvents.run_completed.connect(_on_run_completed)
	GameEvents.platform_landed.connect(_on_platform_landed)
	GameEvents.score_changed.connect(_on_score_changed)
	GameEvents.chain_changed.connect(_on_chain_changed)
	GameEvents.coins_earned.connect(_on_coins_earned)

func reload() -> void:
	_check_date()


func _check_date() -> void:
	var today = Time.get_date_string_from_system()
	if SaveManager.data.get("mission_date", "") != today:
		SaveManager.data["mission_date"] = today
		
		# Seed random so it's consistent for today (but use a different offset than daily challenge)
		var seed_val = today.hash() + 999 
		seed(seed_val)
		
		# Shuffle a copy of the missions array and pick the first 3
		var pool = ALL_MISSIONS.duplicate()
		pool.shuffle()
		var chosen = [pool[0], pool[1], pool[2]]
		
		var saved_missions = []
		for m in chosen:
			saved_missions.append({
				"id": m["id"],
				"progress": 0,
				"completed": false,
				"claimed": false
			})
			
		SaveManager.data["missions"] = saved_missions
		SaveManager.save_data()
	
	_load_state()


func _load_state() -> void:
	current_missions.clear()
	var saved = SaveManager.data.get("missions", [])
	
	for s_m in saved:
		var m_id = s_m.get("id", "")
		var base_data = _get_mission_data(m_id)
		if base_data != null:
			var combined = {
				"id": m_id,
				"data": base_data,
				"progress": s_m.get("progress", 0),
				"completed": s_m.get("completed", false),
				"claimed": s_m.get("claimed", false)
			}
			current_missions.append(combined)


func _get_mission_data(id: String):
	for m in ALL_MISSIONS:
		if m["id"] == id:
			return m
	return null


func claim_reward(index: int, multiplier: int = 1) -> void:
	if index >= 0 and index < current_missions.size():
		var m = current_missions[index]
		if m["completed"] and not m["claimed"]:
			m["claimed"] = true
			# Update save data array
			SaveManager.data["missions"][index]["claimed"] = true
			CurrencyManager.add_coins(m["data"]["reward"] * multiplier)
			SaveManager.save_data()
			progress_updated.emit()


func _add_progress(type: String, amount: int, is_absolute: bool = false) -> void:
	var changed = false
	
	for i in range(current_missions.size()):
		var m = current_missions[i]
		if m["completed"]:
			continue
			
		if m["data"]["type"] == type:
			if is_absolute:
				if amount > m["progress"]:
					m["progress"] = amount
					changed = true
			else:
				m["progress"] += amount
				changed = true
				
			if m["progress"] >= m["data"]["target"]:
				m["progress"] = m["data"]["target"]
				m["completed"] = true
				SaveManager.data["missions"][i]["completed"] = true
				mission_completed.emit(i)
				
			# Sync to save data
			SaveManager.data["missions"][i]["progress"] = m["progress"]

	if changed:
		SaveManager.save_data()
		progress_updated.emit()


# --- Event Listeners ---

func _on_run_completed() -> void:
	_add_progress("runs", 1)


func _on_platform_landed(is_perfect: bool) -> void:
	_add_progress("landings", 1)
	if is_perfect:
		_add_progress("perfect", 1)


func _on_score_changed(new_total: int, _amount_gained: int) -> void:
	_add_progress("score", new_total, true)


func _on_chain_changed(new_chain: int) -> void:
	_add_progress("chain", new_chain, true)


func _on_coins_earned(amount: int) -> void:
	_add_progress("coins", amount)
