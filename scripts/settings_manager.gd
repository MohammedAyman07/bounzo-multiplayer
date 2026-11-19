extends Node

# =====================================================
# SETTINGS MANAGER
# Central state for all player preferences.
# Registered as Autoload "SettingsManager" in project.godot.
# Reads/writes through SaveManager - no second save system.
# =====================================================

signal settings_changed
signal progress_reset

var music_enabled: bool     = true
var music_volume: float     = 0.70
var sfx_enabled: bool       = true
var sfx_volume: float       = 1.00
var vibration_enabled: bool = true


func _ready() -> void:
	_load_from_save()
	call_deferred("_apply_all")


func _load_from_save() -> void:
	music_enabled     = SaveManager.data.get("music_enabled",     true)
	music_volume      = SaveManager.data.get("music_volume",      0.70)
	sfx_enabled       = SaveManager.data.get("sfx_enabled",       true)
	sfx_volume        = SaveManager.data.get("sfx_volume",        1.00)
	vibration_enabled = SaveManager.data.get("vibration_enabled", true)


func _apply_all() -> void:
	_apply_music_bus()
	_apply_sfx_bus()


func _apply_music_bus() -> void:
	var idx = AudioServer.get_bus_index("Music")
	if idx < 0: return
	AudioServer.set_bus_mute(idx, not music_enabled)
	if music_enabled:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))
	else:
		AudioServer.set_bus_volume_db(idx, -80.0)


func _apply_sfx_bus() -> void:
	var idx = AudioServer.get_bus_index("SFX")
	if idx < 0: return
	AudioServer.set_bus_mute(idx, not sfx_enabled)
	if sfx_enabled:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))
	else:
		AudioServer.set_bus_volume_db(idx, -80.0)


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	_apply_music_bus()
	_save()
	settings_changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0 and music_enabled:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))
	_save()


func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	_apply_sfx_bus()
	_save()
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0 and sfx_enabled:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))
	_save()


func set_vibration_enabled(value: bool) -> void:
	vibration_enabled = value
	_save()
	settings_changed.emit()


func _save() -> void:
	SaveManager.data["music_enabled"]     = music_enabled
	SaveManager.data["music_volume"]      = music_volume
	SaveManager.data["sfx_enabled"]       = sfx_enabled
	SaveManager.data["sfx_volume"]        = sfx_volume
	SaveManager.data["vibration_enabled"] = vibration_enabled
	SaveManager.save_data()


func reset_all_progress() -> void:
	SaveManager._create_default_save()
	SaveManager.data["music_enabled"]     = true
	SaveManager.data["music_volume"]      = 0.70
	SaveManager.data["sfx_enabled"]       = true
	SaveManager.data["sfx_volume"]        = 1.00
	SaveManager.data["vibration_enabled"] = true
	SaveManager.save_data()
	_load_from_save()
	_apply_all()
	if CurrencyManager.has_method("reload"): 
		CurrencyManager.reload()
	else:
		CurrencyManager.coins_changed.emit(CurrencyManager.get_coins())
	
	if GameState.has_method("reload"): GameState.reload()
	if MissionManager.has_method("reload"): MissionManager.reload()
	if DailyChallengeManager.has_method("reload"): DailyChallengeManager.reload()
	
	settings_changed.emit()
	progress_reset.emit()
	
	get_tree().paused = false
	get_tree().reload_current_scene()

