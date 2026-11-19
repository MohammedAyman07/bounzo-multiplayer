extends SceneTree

func _init():
	print("HAS_GAME_STATE: ", Engine.has_singleton("GameState"))
	print("HAS_WORLD_PHASE_MANAGER: ", Engine.has_singleton("WorldPhaseManager"))
	quit()
