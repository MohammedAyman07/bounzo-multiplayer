extends Node

# =====================================================
# DAILY CHALLENGE MANAGER
# Generates and tracks daily challenges.
# Registered as Autoload "DailyChallengeManager" in project.godot.
# =====================================================

signal progress_updated
signal challenge_completed

const CHALLENGES = [
	{"id": "c1", "type": "score", "target": 300, "reward": 100, "desc": "Reach a score of 300"},
	{"id": "c2", "type": "chain", "target": 10, "reward": 100, "desc": "Reach a chain of 10"},
	{"id": "c3", "type": "perfect", "target": 3, "reward": 100, "desc": "Get 3 perfect landings"},
	{"id": "c4", "type": "score", "target": 750, "reward": 250, "desc": "Reach a score of 750"},
	{"id": "c5", "type": "chain", "target": 20, "reward": 250, "desc": "Reach a chain of 20"},
	{"id": "c6", "type": "perfect", "target": 7, "reward": 250, "desc": "Get 7 perfect landings"},
	{"id": "c7", "type": "runs", "target": 3, "reward": 100, "desc": "Play 3 runs"},
	{"id": "c8", "type": "coins", "target": 100, "reward": 250, "desc": "Earn 100 coins"},
	{"id": "c9", "type": "score", "target": 1500, "reward": 500, "desc": "Reach a score of 1500"},
	{"id": "c10", "type": "chain", "target": 35, "reward": 500, "desc": "Reach a chain of 35"},
	{"id": "c11", "type": "perfect", "target": 15, "reward": 500, "desc": "Get 15 perfect landings"}
]

var current_challenge: Dictionary = {}
var progress: int = 0
var completed: bool = false
var claimed: bool = false

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
	if SaveManager.data.get("daily_date", "") != today:
		# New day, generate new challenge
		SaveManager.data["daily_date"] = today
		
		# Seed random generator with the date so it's consistent all day
		# Convert date string to an integer seed
		var seed_val = today.hash()
		seed(seed_val)
		
		var chosen = CHALLENGES[randi() % CHALLENGES.size()]
		
		SaveManager.data["daily_challenge_id"] = chosen["id"]
		SaveManager.data["daily_challenge_progress"] = 0
		SaveManager.data["daily_challenge_completed"] = false
		SaveManager.data["daily_challenge_claimed"] = false
		SaveManager.save_data()
	
	_load_state()


func _load_state() -> void:
	var c_id = SaveManager.data.get("daily_challenge_id", "")
	for c in CHALLENGES:
		if c["id"] == c_id:
			current_challenge = c
			break
			
	progress = SaveManager.data.get("daily_challenge_progress", 0)
	completed = SaveManager.data.get("daily_challenge_completed", false)
	claimed = SaveManager.data.get("daily_challenge_claimed", false)


func claim_reward(multiplier: int = 1) -> void:
	if completed and not claimed:
		claimed = true
		SaveManager.data["daily_challenge_claimed"] = true
		CurrencyManager.add_coins(current_challenge["reward"] * multiplier)
		SaveManager.save_data()
		progress_updated.emit()


func _add_progress(amount: int, is_absolute: bool = false) -> void:
	if completed: return
	
	if is_absolute:
		# For absolute stats like "Reach chain of X", we don't accumulate across runs.
		# But wait, progress tracking might want to show highest achieved.
		if amount > progress:
			progress = amount
	else:
		progress += amount
		
	SaveManager.data["daily_challenge_progress"] = progress
	
	if progress >= current_challenge["target"]:
		progress = current_challenge["target"]
		completed = true
		SaveManager.data["daily_challenge_completed"] = true
		SaveManager.save_data()
		challenge_completed.emit()
	else:
		SaveManager.save_data()
	
	progress_updated.emit()


# --- Event Listeners ---

func _on_run_completed() -> void:
	if current_challenge["type"] == "runs":
		_add_progress(1)


func _on_platform_landed(is_perfect: bool) -> void:
	if is_perfect and current_challenge["type"] == "perfect":
		_add_progress(1)


func _on_score_changed(new_total: int, _amount_gained: int) -> void:
	if current_challenge["type"] == "score":
		_add_progress(new_total, true)


func _on_chain_changed(new_chain: int) -> void:
	if current_challenge["type"] == "chain":
		_add_progress(new_chain, true)


func _on_coins_earned(amount: int) -> void:
	if current_challenge["type"] == "coins":
		_add_progress(amount)
