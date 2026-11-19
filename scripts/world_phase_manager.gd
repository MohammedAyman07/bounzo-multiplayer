extends Node

signal phase_changed(new_phase_id: int, phase_name: String)

var current_phase_id: int = 1
var current_phase_name: String = "NEON CITY"
var current_phase_config: Dictionary = {}
var highest_phase_reached: int = 1

const PHASES = [
	{
		"id": 1,
		"name": "NEON CITY",
		"min_score": 0,
		"sky": Color(0.02, 0.01, 0.06, 1.0),
		"horizon": Color(0.08, 0.03, 0.15, 1.0),
		"grid": Color(0.85, 0.20, 1.00, 0.12),
		"city_bg": Color(0.02, 0.0, 0.05, 1.0),
		"city_mid": Color(0.04, 0.01, 0.10, 1.0),
		"city_fg": Color(0.08, 0.01, 0.20, 1.0),
		"city_hilite": Color(0.40, 0.05, 0.80, 0.6),
		"platform_speed_mult": 1.0,
		"platform_width_mult": 1.0,
		"difficulty_mult": 1.0
	},
	{
		"id": 2,
		"name": "CYBER HIGHWAY",
		"min_score": 1000,
		"sky": Color(0.01, 0.04, 0.1, 1.0),
		"horizon": Color(0.02, 0.1, 0.25, 1.0),
		"grid": Color(0.1, 0.8, 1.0, 0.2),
		"city_bg": Color(0.01, 0.02, 0.08, 1.0),
		"city_mid": Color(0.02, 0.05, 0.15, 1.0),
		"city_fg": Color(0.04, 0.1, 0.25, 1.0),
		"city_hilite": Color(0.1, 0.8, 1.0, 0.6),
		"platform_speed_mult": 1.05,
		"platform_width_mult": 0.95,
		"difficulty_mult": 1.1
	},
	{
		"id": 3,
		"name": "NEON STORM",
		"min_score": 2500,
		"sky": Color(0.05, 0.01, 0.08, 1.0),
		"horizon": Color(0.12, 0.02, 0.15, 1.0),
		"grid": Color(0.0, 0.9, 0.8, 0.15),
		"city_bg": Color(0.04, 0.01, 0.06, 1.0),
		"city_mid": Color(0.08, 0.01, 0.12, 1.0),
		"city_fg": Color(0.15, 0.02, 0.2, 1.0),
		"city_hilite": Color(0.0, 1.0, 0.8, 0.5),
		"platform_speed_mult": 1.1,
		"platform_width_mult": 0.9,
		"difficulty_mult": 1.2
	},
	{
		"id": 4,
		"name": "SKY RUINS",
		"min_score": 5000,
		"sky": Color(0.08, 0.0, 0.15, 1.0),
		"horizon": Color(0.2, 0.0, 0.3, 1.0),
		"grid": Color(0.8, 0.4, 1.0, 0.1),
		"city_bg": Color(0.06, 0.0, 0.1, 1.0),
		"city_mid": Color(0.12, 0.0, 0.2, 1.0),
		"city_fg": Color(0.18, 0.0, 0.3, 1.0),
		"city_hilite": Color(0.9, 0.5, 1.0, 0.4),
		"platform_speed_mult": 1.15,
		"platform_width_mult": 0.85,
		"difficulty_mult": 1.3
	},
	{
		"id": 5,
		"name": "GRAVITY CORE",
		"min_score": 8000,
		"sky": Color(0.02, 0.0, 0.08, 1.0),
		"horizon": Color(0.0, 0.3, 0.4, 1.0),
		"grid": Color(0.0, 1.0, 1.0, 0.25),
		"city_bg": Color(0.01, 0.0, 0.06, 1.0),
		"city_mid": Color(0.02, 0.1, 0.15, 1.0),
		"city_fg": Color(0.0, 0.2, 0.3, 1.0),
		"city_hilite": Color(0.0, 1.0, 1.0, 0.7),
		"platform_speed_mult": 1.2,
		"platform_width_mult": 0.8,
		"difficulty_mult": 1.4
	},
	{
		"id": 6,
		"name": "VOID RUN",
		"min_score": 12000,
		"sky": Color(0.0, 0.0, 0.0, 1.0),
		"horizon": Color(0.01, 0.01, 0.05, 1.0),
		"grid": Color(0.2, 0.2, 0.8, 0.1),
		"city_bg": Color(0.0, 0.0, 0.0, 1.0),
		"city_mid": Color(0.0, 0.0, 0.02, 1.0),
		"city_fg": Color(0.01, 0.01, 0.04, 1.0),
		"city_hilite": Color(0.3, 0.3, 1.0, 0.5),
		"platform_speed_mult": 1.25,
		"platform_width_mult": 0.75,
		"difficulty_mult": 1.5
	},
	{
		"id": 7,
		"name": "CHAOS MODE",
		"min_score": 20000,
		"sky": Color(0.1, 0.0, 0.1, 1.0),
		"horizon": Color(0.3, 0.0, 0.0, 1.0),
		"grid": Color(1.0, 0.0, 0.5, 0.3),
		"city_bg": Color(0.1, 0.0, 0.05, 1.0),
		"city_mid": Color(0.2, 0.0, 0.1, 1.0),
		"city_fg": Color(0.3, 0.0, 0.0, 1.0),
		"city_hilite": Color(1.0, 0.0, 0.3, 0.8),
		"platform_speed_mult": 1.3,
		"platform_width_mult": 0.7,
		"difficulty_mult": 1.6
	}
]


func _ready() -> void:
	current_phase_config = PHASES[0]
	
	if Engine.has_singleton("SaveManager"):
		var sm = Engine.get_singleton("SaveManager")
		if sm.data:
			highest_phase_reached = sm.data.get("highest_phase_reached", 1)


func reload_from_save() -> void:
	highest_phase_reached = SaveManager.data.get("highest_phase_reached", 1)


func reset_for_new_game() -> void:
	var old_id = current_phase_id
	current_phase_id = 1
	current_phase_name = PHASES[0]["name"]
	current_phase_config = PHASES[0]
	
	if Engine.has_singleton("SaveManager"):
		highest_phase_reached = Engine.get_singleton("SaveManager").data.get("highest_phase_reached", 1)
		
	if old_id != 1:
		phase_changed.emit(current_phase_id, current_phase_name)


func update_phase_from_score(score: int) -> void:
	var new_phase = PHASES[0]
	
	for i in range(PHASES.size() - 1, -1, -1):
		if score >= PHASES[i]["min_score"]:
			new_phase = PHASES[i]
			break
			
	if new_phase["id"] != current_phase_id:
		current_phase_id = new_phase["id"]
		current_phase_name = new_phase["name"]
		current_phase_config = new_phase
		
		phase_changed.emit(current_phase_id, current_phase_name)
		
		if current_phase_id > highest_phase_reached:
			highest_phase_reached = current_phase_id
			if Engine.has_singleton("SaveManager"):
				var sm = Engine.get_singleton("SaveManager")
				sm.data["highest_phase_reached"] = highest_phase_reached
				sm.save_data()
