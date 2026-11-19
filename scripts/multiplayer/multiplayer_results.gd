class_name MultiplayerResults
extends Control

# ==============================================================================
# MULTIPLAYER MATCH RESULTS SCREEN
# Displays 1st to 4th place rankings, final scores, heights, and rematch controls.
# ==============================================================================

const Protocol = preload("res://scripts/multiplayer/multiplayer_protocol.gd")

@onready var podium_container: VBoxContainer = $SafeContainer/VBox/PodiumContainer
@onready var rematch_btn: Button = $SafeContainer/VBox/ButtonsHBox/RematchBtn
@onready var lobby_btn: Button = $SafeContainer/VBox/ButtonsHBox/LobbyBtn
@onready var menu_btn: Button = $SafeContainer/VBox/ButtonsHBox/MenuBtn
@onready var host_status_lbl: Label = $SafeContainer/VBox/HostStatusLabel

var is_host: bool = false

func _ready() -> void:
	MultiplayerManager.room_updated.connect(_on_room_updated)
	MultiplayerManager.countdown_started.connect(_on_countdown_started)

	_check_host_status()
	_populate_results()

	rematch_btn.pressed.connect(_on_rematch_pressed)
	lobby_btn.pressed.connect(_on_lobby_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _check_host_status() -> void:
	var room = MultiplayerManager.current_room
	var local_id = multiplayer.get_unique_id()
	is_host = (room.get("host_id", 0) == local_id)

	if is_host:
		rematch_btn.show()
		host_status_lbl.hide()
	else:
		rematch_btn.hide()
		host_status_lbl.show()
		host_status_lbl.text = "Waiting for host to rematch..."

func _populate_results() -> void:
	for child in podium_container.get_children():
		child.queue_free()

	var results = MultiplayerManager.last_results
	if results.is_empty():
		# Fallback display if viewing results locally
		results = [
			{"rank": 1, "name": "Player 1", "score": 1200, "height": 3400.0, "slot": 0},
			{"rank": 2, "name": "Player 2", "score": 850, "height": 2100.0, "slot": 1}
		]

	for entry in results:
		var rank: int = int(entry.get("rank", 1))
		var p_name: String = str(entry.get("name", "Player"))
		var score: int = int(entry.get("score", 0))
		var slot: int = int(entry.get("slot", 0))

		var slot_color: Color = Color.WHITE
		if slot >= 0 and slot < Protocol.SLOT_COLORS.size():
			slot_color = Protocol.SLOT_COLORS[slot]

		var row = PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 72)
		row.add_theme_stylebox_override("panel", UITheme.glass_panel_accent(slot_color, UITheme.RADIUS_MD))

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		row.add_child(hbox)

		# Rank Pill
		var rank_lbl = Label.new()
		rank_lbl.text = "#%d" % rank
		var rank_color = UITheme.GOLD if rank == 1 else (UITheme.WHITE if rank == 2 else UITheme.MUTED)
		rank_lbl.label_settings = UITheme.ls(28, rank_color)
		rank_lbl.custom_minimum_size = Vector2(50, 0)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(rank_lbl)

		# Player Info
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(info_vbox)

		var name_lbl = Label.new()
		name_lbl.text = p_name
		name_lbl.label_settings = UITheme.ls(20, slot_color)
		info_vbox.add_child(name_lbl)

		var title_txt = "WINNER" if rank == 1 else "SURVIVOR"
		var sub_lbl = Label.new()
		sub_lbl.text = title_txt
		sub_lbl.label_settings = UITheme.ls(12, UITheme.MUTED)
		info_vbox.add_child(sub_lbl)

		# Score
		var score_lbl = Label.new()
		score_lbl.text = "%d PTS" % score
		score_lbl.label_settings = UITheme.ls(22, UITheme.YELLOW)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(score_lbl)

		podium_container.add_child(row)

func _on_rematch_pressed() -> void:
	if is_host:
		MultiplayerManager.request_rematch()

func _on_lobby_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_lobby.tscn")

func _on_menu_pressed() -> void:
	MultiplayerManager.leave_current_room()
	MultiplayerManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_room_updated(room_data: Dictionary) -> void:
	if room_data.get("state", 0) == Protocol.RoomState.LOBBY:
		get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_lobby.tscn")

func _on_countdown_started(_info: Dictionary) -> void:
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_game.tscn")
