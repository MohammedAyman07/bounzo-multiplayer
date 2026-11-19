extends Node

# =====================================================
# COSMETIC DATA
# Contains configurations for all Balls and Trails
# Registered as Autoload "CosmeticData" in project.godot.
# =====================================================

signal cosmetics_changed

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const BALLS = {
	"basic": {
		"id": "basic",
		"name": "BASIC",
		"price": 0,
		"core": Color(1.0, 1.0, 1.0, 1.0),
		"inner": Color(0.0, 0.9, 1.0, 1.0),
		"outer": Color(0.0, 0.5, 1.0, 0.6),
		"glow": Color(0.0, 0.3, 1.0, 0.15)
	},
	"fire": {
		"id": "fire",
		"name": "FIRE",
		"price": 500,
		"core": Color(1.0, 0.9, 0.5, 1.0),
		"inner": Color(1.0, 0.4, 0.0, 1.0),
		"outer": Color(1.0, 0.1, 0.0, 0.6),
		"glow": Color(1.0, 0.0, 0.0, 0.15)
	},
	"lightning": {
		"id": "lightning",
		"name": "LIGHTNING",
		"price": 1000,
		"core": Color(1.0, 1.0, 1.0, 1.0),
		"inner": Color(1.0, 0.9, 0.0, 1.0),
		"outer": Color(0.0, 0.4, 1.0, 0.6),
		"glow": Color(0.0, 0.2, 1.0, 0.15)
	},
	"crystal": {
		"id": "crystal",
		"name": "CRYSTAL",
		"price": 2000,
		"core": Color(1.0, 1.0, 1.0, 1.0),
		"inner": Color(0.8, 1.0, 1.0, 1.0),
		"outer": Color(0.4, 0.9, 1.0, 0.5),
		"glow": Color(0.4, 0.9, 1.0, 0.2)
	},
	"shadow": {
		"id": "shadow",
		"name": "SHADOW",
		"price": 3500,
		"core": Color(0.3, 0.0, 0.5, 1.0),
		"inner": Color(0.1, 0.0, 0.2, 1.0),
		"outer": Color(0.4, 0.0, 0.8, 0.6),
		"glow": Color(0.2, 0.0, 0.4, 0.2)
	},
	"neon": {
		"id": "neon",
		"name": "NEON",
		"price": 5000,
		"core": Color(1.0, 1.0, 1.0, 1.0),
		"inner": Color(1.0, 0.1, 0.78, 1.0), # Magenta
		"outer": Color(0.0, 0.85, 1.0, 0.6), # Cyan
		"glow": Color(1.0, 0.82, 0.12, 0.15) # Yellow
	}
}


const TRAILS = {
	"basic": {
		"id": "basic",
		"name": "BASIC",
		"price": 0,
		"inner": Color(0.0, 0.9, 1.0, 1.0),
		"outer": Color(0.0, 0.4, 1.0, 1.0),
		"spark": Color(0.5, 1.0, 1.0, 1.0)
	},
	"fire": {
		"id": "fire",
		"name": "FIRE",
		"price": 500,
		"inner": Color(1.0, 0.4, 0.0, 1.0),
		"outer": Color(1.0, 0.1, 0.0, 1.0),
		"spark": Color(1.0, 0.8, 0.2, 1.0)
	},
	"lightning": {
		"id": "lightning",
		"name": "LIGHTNING",
		"price": 1000,
		"inner": Color(1.0, 0.9, 0.0, 1.0),
		"outer": Color(0.0, 0.5, 1.0, 1.0),
		"spark": Color(1.0, 1.0, 1.0, 1.0)
	},
	"plasma": {
		"id": "plasma",
		"name": "PLASMA",
		"price": 2000,
		"inner": Color(0.7, 0.0, 1.0, 1.0),
		"outer": Color(1.0, 0.0, 0.8, 1.0),
		"spark": Color(0.9, 0.5, 1.0, 1.0)
	},
	"rainbow": {
		"id": "rainbow",
		"name": "RAINBOW",
		"price": 3500,
		"inner": Color(1.0, 1.0, 1.0, 1.0), # Rainbow logic will override this in _draw if needed, or we just rely on spark logic
		"outer": Color(1.0, 0.0, 0.0, 1.0),
		"spark": Color(0.0, 1.0, 0.0, 1.0)
	}
}


func get_ball(id: String) -> Dictionary:
	if BALLS.has(id):
		return BALLS[id]
	return BALLS["basic"]


func get_trail(id: String) -> Dictionary:
	if TRAILS.has(id):
		return TRAILS[id]
	return TRAILS["basic"]


# Unlock helpers

func unlock_ball(id: String) -> void:
	var unlocked = SaveManager.data.get("unlocked_balls", [])
	if not id in unlocked:
		unlocked.append(id)
		SaveManager.data["unlocked_balls"] = unlocked
		SaveManager.save_data()


func unlock_trail(id: String) -> void:
	var unlocked = SaveManager.data.get("unlocked_trails", [])
	if not id in unlocked:
		unlocked.append(id)
		SaveManager.data["unlocked_trails"] = unlocked
		SaveManager.save_data()


func is_ball_unlocked(id: String) -> bool:
	if id == "basic": return true
	return id in SaveManager.data.get("unlocked_balls", [])


func is_trail_unlocked(id: String) -> bool:
	if id == "basic": return true
	return id in SaveManager.data.get("unlocked_trails", [])


func equip_ball(id: String) -> void:
	SaveManager.data["selected_ball"] = id
	SaveManager.save_data()
	cosmetics_changed.emit()


func equip_trail(id: String) -> void:
	SaveManager.data["selected_trail"] = id
	SaveManager.save_data()
	cosmetics_changed.emit()
