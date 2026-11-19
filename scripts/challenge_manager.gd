extends Node

# =====================================================
# CHALLENGE MANAGER
# Single source of truth for Challenge Mode.
# =====================================================

const CHALLENGE_TEST_MODE: bool = false

enum State {
	INACTIVE,
	COUNTDOWN,
	RUNNING,
	PAUSED,
	SUCCESS,
	FAILED
}

var current_state: State = State.INACTIVE
var active_challenge_id: String = ""

# The authoritative time left
var time_left: float = 0.0

const RANKS = [
	{"id": "bronze",      "name": "BRONZE",      "required_stars": 3, "reward": 0,    "color": Color(0.8, 0.5, 0.2), "texture": "res://bronze_logo.png"}, # Metallic Bronze
	{"id": "silver",      "name": "SILVER",      "required_stars": 5, "reward": 200,  "color": Color(0.8, 0.8, 0.8), "texture": "res://silver_logo.png"}, # Polished Silver
	{"id": "gold",        "name": "GOLD",        "required_stars": 5, "reward": 300,  "color": Color(1.0, 0.84, 0.0), "texture": "res://gold_logo.png"}, # Premium Gold
	{"id": "platinum",    "name": "PLATINUM",    "required_stars": 5, "reward": 500,  "color": Color(0.3, 0.8, 1.0), "texture": "res://platinum_logo.png"}, # Electric Blue
	{"id": "diamond",     "name": "DIAMOND",     "required_stars": 6, "reward": 750,  "color": Color(1.0, 0.2, 0.8), "texture": "res://diamond_logo.png"}, # Vibrant Pink
	{"id": "master",      "name": "MASTER",      "required_stars": 6, "reward": 1000, "color": Color(1.0, 0.0, 0.0), "texture": "res://master_logo.png"}, # Crimson Red
	{"id": "grandmaster", "name": "GRANDMASTER", "required_stars": 6, "reward": 2000, "color": Color(1.0, 0.95, 0.0), "texture": "res://grandmaster_logo.png"}  # Bright Gold
]

const CHALLENGES = {
	# BRONZE (EASY) - Target: 1500-2500 - 3 Challenges
	"bronze_1": { "id": "bronze_1", "rank": "bronze", "name": "WARMUP", "target": 1500, "time": 120.0, "difficulty": "EASY", "entry": 50, "reward": 250, "rules": ["flicker"], "star_value": 1 },
	"bronze_2": { "id": "bronze_2", "rank": "bronze", "name": "MOVING UP", "target": 2000, "time": 120.0, "difficulty": "EASY", "entry": 50, "reward": 250, "rules": ["moving"], "star_value": 1 },
	"bronze_3": { "id": "bronze_3", "rank": "bronze", "name": "BRONZE PEAK", "target": 2500, "time": 105.0, "difficulty": "EASY", "entry": 50, "reward": 250, "rules": ["moving"], "star_value": 1 },
	
	# SILVER (MEDIUM) - Target: 3000-4000 - 4 Challenges (Need 5 stars, one is 2 stars)
	"silver_1": { "id": "silver_1", "rank": "silver", "name": "ELEVATION", "target": 3000, "time": 120.0, "difficulty": "MEDIUM", "entry": 100, "reward": 500, "rules": ["moving", "shrink"], "star_value": 1 },
	"silver_2": { "id": "silver_2", "rank": "silver", "name": "SHATTER", "target": 3500, "time": 120.0, "difficulty": "MEDIUM", "entry": 100, "reward": 500, "rules": ["moving", "fragile", "flicker"], "star_value": 1 },
	"silver_3": { "id": "silver_3", "rank": "silver", "name": "COMBO BUILDER", "target": 1500, "time": 120.0, "difficulty": "MEDIUM", "entry": 100, "reward": 500, "rules": ["shrink", "chain_15"], "star_value": 1 },
	"silver_4": { "id": "silver_4", "rank": "silver", "name": "SILVER SUMMIT", "target": 4000, "time": 135.0, "difficulty": "MEDIUM", "entry": 100, "reward": 500, "rules": ["vanishing", "faster_moving", "flicker"], "star_value": 2 },
	
	# GOLD (HARD) - Target: 5000-7000 - 4 Challenges (Need 5 stars)
	"gold_1": { "id": "gold_1", "rank": "gold", "name": "DANGER ZONE", "target": 5000, "time": 150.0, "difficulty": "HARD", "entry": 200, "reward": 900, "rules": ["moving", "shrink", "flicker"], "star_value": 1 },
	"gold_2": { "id": "gold_2", "rank": "gold", "name": "GHOST JUMPS", "target": 5500, "time": 150.0, "difficulty": "HARD", "entry": 200, "reward": 900, "rules": ["closing", "vanishing", "faster_moving"], "star_value": 1 },
	"gold_3": { "id": "gold_3", "rank": "gold", "name": "GOLDEN CHAIN", "target": 6000, "time": 150.0, "difficulty": "HARD", "entry": 200, "reward": 900, "rules": ["risk_routes", "shrink", "chain_20"], "star_value": 1 },
	"gold_4": { "id": "gold_4", "rank": "gold", "name": "GOLD PEAK", "target": 7000, "time": 135.0, "difficulty": "VERY HARD", "entry": 200, "reward": 900, "rules": ["wind", "closing", "faster_moving"], "star_value": 2 },
	
	# PLATINUM (VERY HARD) - Target: 7500-10000 - 4 Challenges (Need 5 stars)
	"platinum_1": { "id": "platinum_1", "rank": "platinum", "name": "HURRICANE", "target": 7500, "time": 180.0, "difficulty": "VERY HARD", "entry": 350, "reward": 1500, "rules": ["wind", "faster_moving", "flicker"], "star_value": 1 },
	"platinum_2": { "id": "platinum_2", "rank": "platinum", "name": "FADING PATH", "target": 8000, "time": 180.0, "difficulty": "VERY HARD", "entry": 350, "reward": 1500, "rules": ["closing", "vanishing", "faster_moving"], "star_value": 1 },
	"platinum_3": { "id": "platinum_3", "rank": "platinum", "name": "PLATINUM LINK", "target": 9000, "time": 180.0, "difficulty": "VERY HARD", "entry": 350, "reward": 1500, "rules": ["shrink", "chain_25"], "star_value": 1 },
	"platinum_4": { "id": "platinum_4", "rank": "platinum", "name": "PLATINUM PEAK", "target": 10000, "time": 165.0, "difficulty": "EXPERT", "entry": 350, "reward": 1500, "rules": ["shrink", "wind", "risk_routes"], "star_value": 2 },
	
	# DIAMOND (EXPERT) - Target: 10000-15000 - 4 Challenges (Need 6 stars)
	"diamond_1": { "id": "diamond_1", "rank": "diamond", "name": "GHOST WIND", "target": 10000, "time": 210.0, "difficulty": "EXPERT", "entry": 600, "reward": 2500, "rules": ["fragile", "wind", "flicker"], "star_value": 1 },
	"diamond_2": { "id": "diamond_2", "rank": "diamond", "name": "CRUSHER", "target": 12000, "time": 210.0, "difficulty": "EXPERT", "entry": 600, "reward": 2500, "rules": ["closing", "faster_moving"], "star_value": 1 },
	"diamond_3": { "id": "diamond_3", "rank": "diamond", "name": "DIAMOND CHAIN", "target": 13500, "time": 210.0, "difficulty": "EXPERT", "entry": 600, "reward": 2500, "rules": ["risk_routes", "chain_30"], "star_value": 2 },
	"diamond_4": { "id": "diamond_4", "rank": "diamond", "name": "DIAMOND PEAK", "target": 15000, "time": 180.0, "difficulty": "MASTER", "entry": 600, "reward": 2500, "rules": ["advanced_combinations", "shrink"], "star_value": 2 },
	
	# MASTER (BRUTAL) - Target: 15000-20000 - 4 Challenges (Need 6 stars)
	"master_1": { "id": "master_1", "rank": "master", "name": "SPEED RUN", "target": 15000, "time": 150.0, "difficulty": "MASTER", "entry": 2000, "reward": 5000, "rules": ["faster_moving", "advanced_combinations"], "star_value": 1 },
	"master_2": { "id": "master_2", "rank": "master", "name": "TIGHTROPE", "target": 16500, "time": 210.0, "difficulty": "MASTER", "entry": 2000, "reward": 5000, "rules": ["small_safe_zones", "fragile", "vanishing"], "star_value": 1 },
	"master_3": { "id": "master_3", "rank": "master", "name": "MASTER CHAIN", "target": 18000, "time": 210.0, "difficulty": "MASTER", "entry": 2000, "reward": 5000, "rules": ["chain_40", "wind", "moving"], "star_value": 2 },
	"master_4": { "id": "master_4", "rank": "master", "name": "MASTER PEAK", "target": 20000, "time": 210.0, "difficulty": "EXTREME", "entry": 2000, "reward": 5000, "rules": ["advanced_combinations", "closing", "faster_moving"], "star_value": 2 },
	
	# GRANDMASTER (EXTREME) - Target: 20000-30000 - 4 Challenges
	"grandmaster_1": { "id": "grandmaster_1", "rank": "grandmaster", "name": "ABSOLUTE CHAOS", "target": 20000, "time": 240.0, "difficulty": "EXTREME", "entry": 5000, "reward": 12000, "rules": ["chaos_mode"], "star_value": 1 },
	"grandmaster_2": { "id": "grandmaster_2", "rank": "grandmaster", "name": "GAUNTLET", "target": 22500, "time": 240.0, "difficulty": "EXTREME", "entry": 5000, "reward": 12000, "rules": ["advanced_combinations", "closing", "wind", "fragile"], "star_value": 1 },
	"grandmaster_3": { "id": "grandmaster_3", "rank": "grandmaster", "name": "GRAND CHAIN", "target": 25000, "time": 240.0, "difficulty": "EXTREME", "entry": 5000, "reward": 12000, "rules": ["chain_50", "chaos_mode"], "star_value": 2 },
	"grandmaster_4": { "id": "grandmaster_4", "rank": "grandmaster", "name": "GRANDMASTER PEAK", "target": 30000, "time": 240.0, "difficulty": "LEGENDARY", "entry": 5000, "reward": 12000, "rules": ["chaos_mode", "vanishing", "wind", "closing", "faster_moving"], "star_value": 2 },
}

signal state_changed(new_state)
signal time_updated(time_left)

func _process(delta: float) -> void:
	if current_state == State.RUNNING:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			fail_challenge()
		time_updated.emit(time_left)

func get_effective_entry_fee(id: String) -> int:
	if CHALLENGE_TEST_MODE:
		return 0
	return CHALLENGES[id].entry

func start_challenge(id: String) -> void:
	if not CHALLENGES.has(id): return
	active_challenge_id = id
	time_left = CHALLENGES[id].time
	_set_state(State.COUNTDOWN)

func begin_running() -> void:
	if current_state == State.COUNTDOWN:
		_set_state(State.RUNNING)

func pause_challenge() -> void:
	if current_state == State.RUNNING:
		_set_state(State.PAUSED)

func resume_challenge() -> void:
	if current_state == State.PAUSED:
		_set_state(State.RUNNING)

func revive_challenge(extra_time: float = 15.0) -> void:
	if current_state == State.FAILED or current_state == State.RUNNING or current_state == State.PAUSED:
		if time_left < extra_time:
			time_left = extra_time # Guarantee they have at least extra_time left
		_set_state(State.RUNNING)

func complete_challenge() -> void:
	if current_state == State.RUNNING:
		_set_state(State.SUCCESS)

func fail_challenge() -> void:
	if current_state == State.RUNNING:
		_set_state(State.FAILED)

func cleanup_challenge() -> void:
	active_challenge_id = ""
	time_left = 0.0
	_set_state(State.INACTIVE)

func _set_state(new_state: State) -> void:
	if current_state == new_state: return
	current_state = new_state
	state_changed.emit(current_state)

func is_active() -> bool:
	return current_state != State.INACTIVE

func get_active_challenge() -> Dictionary:
	if is_active() and CHALLENGES.has(active_challenge_id):
		return CHALLENGES[active_challenge_id]
	return {}

# =====================================================
# RANKED SYSTEM
# =====================================================

func get_current_rank() -> Dictionary:
	var unlocked = SaveManager.data.get("unlocked_ranks", ["bronze"])
	if unlocked.size() == 0:
		unlocked = ["bronze"]
		SaveManager.data["unlocked_ranks"] = unlocked
	var top_rank_id = unlocked.back()
	return get_rank_by_id(top_rank_id)

func get_rank_by_id(id: String) -> Dictionary:
	for r in RANKS:
		if r.id == id:
			return r
	return RANKS[0]

func get_next_rank(current_id: String) -> Dictionary:
	for i in range(RANKS.size()):
		if RANKS[i].id == current_id:
			if i + 1 < RANKS.size():
				return RANKS[i + 1]
			return RANKS[i] # Max rank returns itself
	return RANKS[0]

func get_challenges_for_rank(rank_id: String) -> Array:
	var res = []
	for k in CHALLENGES.keys():
		if CHALLENGES[k].rank == rank_id:
			res.append(k)
	return res

func get_stars_in_rank(rank_id: String) -> int:
	var rank_stars = SaveManager.data.get("rank_stars", {})
	return rank_stars.get(rank_id, 0)

func is_rank_unlocked(rank_id: String) -> bool:
	if CHALLENGE_TEST_MODE:
		return true
	var unlocked = SaveManager.data.get("unlocked_ranks", ["bronze"])
	return unlocked.has(rank_id)

func record_challenge_completion(id: String, score: int, time_left_val: float) -> Dictionary:
	var chal = CHALLENGES[id]
	var rank_id = chal.rank
	
	var comp = SaveManager.data.get("challenge_completion_status", {})
	var bests = SaveManager.data.get("challenge_best_scores", {})
	var rank_stars = SaveManager.data.get("rank_stars", {})
	var unlocked = SaveManager.data.get("unlocked_ranks", ["bronze"])
	
	var was_completed = comp.get(id, false)
	var old_best = bests.get(id, 0)
	var new_best = max(old_best, score)
	var is_new_best = false
	var stars_earned = 0
	
	if not was_completed:
		comp[id] = true
		stars_earned = chal.star_value
		is_new_best = true
	else:
		if score > old_best:
			is_new_best = true
			
	if is_new_best:
		bests[id] = new_best
		
	var current_stars = rank_stars.get(rank_id, 0)
	rank_stars[rank_id] = current_stars + stars_earned
	
	var old_top_rank = unlocked.back()
	var rank_up = false
	var newly_unlocked_rank = {}
	
	# Check if this completion unlocked the next rank
	var current_rank_def = get_rank_by_id(rank_id)
	if rank_stars[rank_id] >= current_rank_def.required_stars:
		var next_rank = get_next_rank(rank_id)
		if next_rank.id != rank_id and not unlocked.has(next_rank.id):
			unlocked.append(next_rank.id)
			rank_up = true
			newly_unlocked_rank = next_rank
	
	SaveManager.save_data()
	
	return {
		"stars_earned": stars_earned,
		"old_stars": current_stars,
		"required_stars": current_rank_def.required_stars,
		"old_best": old_best,
		"new_best": new_best,
		"is_new_best": is_new_best,
		"rank_up": rank_up,
		"newly_unlocked_rank": newly_unlocked_rank
	}

func check_rule(rule_name: String) -> bool:
	var chal = get_active_challenge()
	if chal.is_empty(): return false
	return chal.rules.has(rule_name)
