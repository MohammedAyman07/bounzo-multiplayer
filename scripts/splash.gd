extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $SkipButton

var _transition_started: bool = false
var _main_scene_path: String = "res://scenes/game/game.tscn"
var _failed_timeout: float = 3.0
var _timer: float = 0.0

func _ready() -> void:
	# Keep skip hidden initially
	skip_button.modulate.a = 0.0
	skip_button.visible = false
	
	# Stop background music if it was somehow playing
	# Stop background music if it was somehow playing
	AudioManager.stop_music()

	if video_player.stream != null:
		video_player.play()
	else:
		_fallback_to_main()

func _process(delta: float) -> void:
	if _transition_started:
		return
		
	_timer += delta
	
	# Show skip button after 1 second
	if _timer >= 1.0 and not skip_button.visible:
		skip_button.visible = true
		var t = create_tween()
		t.tween_property(skip_button, "modulate:a", 1.0, 0.5)
	
	# Fallback if video is stuck or failed to start
	if _timer >= _failed_timeout and not video_player.is_playing():
		_fallback_to_main()

func _on_video_stream_player_finished() -> void:
	_transition_to_main()

func _on_skip_button_pressed() -> void:
	_transition_to_main()

func _transition_to_main() -> void:
	if _transition_started: return
	_transition_started = true
	
	video_player.stop()
	
	# Resume music
	AudioManager.play_music()
	
	get_tree().change_scene_to_file(_main_scene_path)

func _fallback_to_main() -> void:
	if _transition_started: return
	print("Splash screen fallback triggered.")
	_transition_to_main()
