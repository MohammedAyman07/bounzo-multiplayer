extends Node

# =====================================================
# GAME STATE SINGLETON
# Tracks session score, chain, bests, and multiplier.
# Registered as Autoload "GameState" in project.godot.
# =====================================================

# --- Score ---
var current_score: int = 0
var best_score: int = 0

# --- Chain ---
var current_chain: int = 0
var best_chain: int = 0

var previous_best_score: int = 0

var perfect_count: int = 0
var near_count: int = 0

# --- Records this run ---
var new_score_record: bool = false
var new_chain_record: bool = false
var highest_event: String = ""

# --- Score config ---
const BASE_SCORE_NORMAL: int  = 10
const BASE_SCORE_PERFECT: int = 20

# --- Multiplier thresholds [chain_threshold, multiplier] ascending ---
const MULTIPLIER_TABLE: Array = [
	[41, 5],
	[21, 4],
	[11, 3],
	[6,  2],
	[0,  1],
]

# --- Difficulty thresholds [chain_threshold, stage_name] ascending ---
const DIFFICULTY_TABLE: Array = [
	[41, "INSANE"],
	[21, "HARD"],
	[11, "FAST"],
	[6,  "NORMAL"],
	[0,  "EASY"],
]


func _ready() -> void:
	reload()

func reload() -> void:
	best_score = SaveManager.data.get("best_score", 0)
	previous_best_score = best_score
	best_chain = SaveManager.data.get("best_chain", 0)
	current_score = 0
	current_chain = 0



func get_score_multiplier() -> int:
	for entry in MULTIPLIER_TABLE:
		if current_chain >= entry[0]:
			return entry[1]
	return 1


func get_difficulty_stage() -> String:
	for entry in DIFFICULTY_TABLE:
		if current_chain >= entry[0]:
			return entry[1]
	return "EASY"


func get_previous_difficulty_stage() -> String:
	# Returns what the difficulty was BEFORE the current chain, for milestone detection.
	var prev_chain = current_chain - 1
	for entry in DIFFICULTY_TABLE:
		if prev_chain >= entry[0]:
			return entry[1]
	return "EASY"


var current_streak: int = 0

func add_score_with_grade(grade: int) -> int:
	var base: int = BASE_SCORE_NORMAL
	if grade == 0:
		base = BASE_SCORE_PERFECT
	elif grade == 1:
		base = 15 # GOOD
	elif grade == 3:
		base = 12 # NEAR
		
	var multiplier: int = get_score_multiplier()
	var gained: int = base * multiplier
	current_score += gained
	GameEvents.score_changed.emit(current_score, gained)
	
	var wpm = get_tree().root.get_node_or_null("WorldPhaseManager")
	if wpm:
		wpm.update_phase_from_score(current_score)
		
	return gained

func update_streak(grade: int) -> void:
	if grade == 0 or grade == 1:
		current_streak += 1
	else:
		current_streak = 0

func add_score(is_perfect: bool) -> int:
	return add_score_with_grade(0 if is_perfect else 2)


func increment_chain() -> void:
	current_chain += 1
	GameEvents.chain_changed.emit(current_chain)


func reset_for_new_game() -> void:
	current_score = 0
	current_chain = 0
	current_streak = 0
	perfect_count = 0
	near_count = 0
	new_score_record = false
	new_chain_record = false
	highest_event = ""
	WorldPhaseManager.reset_for_new_game()
	if true:
		best_score = SaveManager.data.get("best_score", 0)
		best_chain = SaveManager.data.get("best_chain", 0)


func finalize_records() -> void:
	new_score_record = false
	new_chain_record = false
	
	if current_score > best_score:
		best_score = current_score
		new_score_record = true
		if true:
			SaveManager.data["best_score"] = best_score
			SaveManager.save_data()
			GameEvents.new_best_score_reached.emit(best_score)
			
	if current_chain > best_chain:
		best_chain = current_chain
		new_chain_record = true
		if true:
			SaveManager.data["best_chain"] = best_chain
			SaveManager.save_data()
			GameEvents.new_best_chain_reached.emit(best_chain)
