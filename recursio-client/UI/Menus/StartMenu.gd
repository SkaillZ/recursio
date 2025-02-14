extends Control
class_name StartMenu

const REMOTE_SERVER_IP: String = "37.252.189.118"

export var world_scene: PackedScene
export var capture_point_scene: PackedScene
export var spawn_point_scene: PackedScene

onready var _start_menu_buttons: VBoxContainer = get_node("CenterContainer/MainMenu")

onready var _btn_play_tutorial = get_node("CenterContainer/MainMenu/PlayTutorial")

onready var _btn_play_online = get_node("CenterContainer/MainMenu/HBoxContainer2/PlayOnline")
onready var _btn_cancel_online = get_node("CenterContainer/MainMenu/HBoxContainer2/CancelOnline")

onready var _btn_play_local = get_node("CenterContainer/MainMenu/HBoxContainer/Btn_PlayLocal")
onready var _lineEdit_local_ip = get_node("CenterContainer/MainMenu/HBoxContainer/LocalIPAddress")
onready var _btn_cancel_local = get_node("CenterContainer/MainMenu/HBoxContainer/CancelLocal")

onready var _btn_settings = get_node("CenterContainer/MainMenu/SettingsButton")
onready var _btn_exit = get_node("CenterContainer/MainMenu/Btn_Exit")

onready var _game_room_search: GameRoomSearch = get_node("CenterContainer/GameRoomSearch")
onready var _game_room_creation: GameRoomCreation = get_node("CenterContainer/GameRoomCreation")
onready var _game_room_lobby: GameRoomLobby = get_node("CenterContainer/GameRoomLobby")
onready var _error_window: ErrorWindow = get_node("CenterContainer/ErrorWindow")
onready var _settings: Control = get_node("CenterContainer/SettingsContainer")

onready var _tutorial: Tutorial = get_node("Tutorial")

onready var _debug_room = Constants.get_value("debug", "debug_room_enabled")

onready var _random_names = TextFileToArray.load_text_file("res://Resources/Data/animal_names.txt")

onready var _stats_hud = get_node("../StatsHUD")
onready var _gameplay_menu = get_node("../GameplayMenu")


var _player_user_name: String
var _player_rpc_id: int

var _in_game: bool = false
var _in_game_room: bool = false

var _world


func _ready():
	
	var _error = _btn_play_tutorial.connect("pressed", self, "_on_play_tutorial")
	_error = _btn_play_online.connect("pressed", self, "_on_play_online")
	_error = _btn_cancel_online.connect("pressed", self, "_on_cancel_online")
	_error = _btn_play_local.connect("pressed", self, "_on_play_local")
	_error = _btn_cancel_local.connect("pressed", self, "_on_cancel_local")
	_error = _btn_settings.connect("pressed", self, "_on_open_settings")
	_error = _btn_exit.connect("pressed", self, "_on_exit")

	_error = _game_room_search.connect("btn_create_game_room_pressed", self, "_on_search_create_game_room_pressed")
	_error = _game_room_search.connect("btn_back_pressed", self, "_on_search_back_pressed")
	_error = _game_room_search.connect("btn_join_game_room_pressed", self, "_on_join_game_room_pressed")
	_error = _game_room_search.connect("visibility_changed", self, "_on_room_search_visibility_changed")

	_error = _game_room_creation.connect("btn_create_game_room_pressed", self, "_on_creation_create_game_room_pressed")
	_error = _game_room_creation.connect("btn_back_pressed", self, "_on_creation_back_pressed")

	_error = _game_room_lobby.connect("btn_leave_pressed", self, "_on_game_room_leave_pressed")
	
	_error = _gameplay_menu.connect("resume_pressed", self, "_on_gameplay_menu_resume_pressed")
	_error = _gameplay_menu.connect("leave_pressed", self, "_on_gameplay_menu_leave_pressed")
	
	_error = Server.connect("server_disconnected", self, "_on_server_disconnected")
	_error = Server.connect("connection_failed", self, "_on_connection_failed")
	
	_error = Server.connect("game_room_created", self, "_on_game_room_created")
	_error = Server.connect("game_rooms_received", self, "_on_game_rooms_received")
	_error = Server.connect("game_room_joined", self, "_on_game_room_joined")
	_error = Server.connect("connection_successful" , self, "_on_connection_successful")
	_error = Server.connect("game_room_ready_received" , self, "_on_game_room_ready_received")
	_error = Server.connect("game_room_not_ready_received" , self, "_on_game_room_not_ready_received")
	_error = Server.connect("load_level_received", self, "_on_load_level_received")
	
	_error = Server.connect("player_disconnected_received", self, "_on_player_disconnected")
	_error = Server.connect("player_left_game_received", self, "_on_player_left_game")
	
	_error = Server.connect("game_room_owner_received", self, "_on_game_room_owner_received")
	_error = Server.connect("level_selected_received", self, "_on_level_selected_received")
	_error = Server.connect("fog_of_war_toggle_received", self, "_on_fog_of_war_toggled")
	
	_error = _tutorial.connect("scenario_started", self, "_on_tutorial_scenario_started")
	_error = _tutorial.connect("scenario_completed", self, "_on_tutorial_scenario_completed")
	_error = _tutorial.connect("btn_back_pressed", self, "_on_tutorial_back_pressed")
	
	# Re-grab button focus
	_error = _settings.connect("visibility_changed", self, "_on_room_search_visibility_changed")
	_error = _error_window.connect("visibility_changed", self, "_on_error_window_visibility_changed")

	_btn_play_tutorial.grab_focus()

	randomize()
	var random_index = randi() % _random_names.size()
	_player_user_name = _random_names[random_index]
	
	_stats_hud.visible = UserSettings.get_setting("developer", "debug")


func _process(_delta):
	if not _in_game:
		return
	
	if Input.is_action_just_pressed("gameplay_menu"):
		_gameplay_menu.visible = !_gameplay_menu.visible
		_toggle_player_input_pause(_gameplay_menu.visible)


func return_to_game_room_lobby():
	_exit_game()
	_world.queue_free()
	_world = null
	$CenterContainer.show()


func return_to_title():
	if _world != null:
		_world.queue_free()
		_world = null
		_in_game = false
	# Reset all sub screens
	_game_room_creation.hide()
	_game_room_lobby.hide()
	_game_room_lobby.reset()
	_game_room_search.hide()
	_game_room_search.reset()
	_in_game_room = false
	# Show start screen
	_start_menu_buttons.show()
	$CenterContainer.show()
	_toggle_enabled_start_menu_buttons(true)
	_btn_play_tutorial.grab_focus()


func _toggle_enabled_start_menu_buttons(enabled: bool):
	_btn_play_online.disabled = !enabled
	_btn_play_local.disabled = !enabled
	_btn_play_tutorial.disabled = !enabled
	_btn_exit.disabled = !enabled


func _on_connection_successful():
	_player_rpc_id = get_tree().get_network_unique_id()
	_start_menu_buttons.hide()
	_btn_cancel_online.hide()
	_btn_cancel_local.hide()
	_game_room_search.show()
	if _debug_room:
		_game_room_search.add_game_room(1, "GameRoom")
		Server.send_join_game_room(1, "Player")
		Server.send_game_room_ready(1)
	else:
		# Load all rooms by default when opening search window
		Server.send_get_game_rooms()


func _on_server_disconnected():
	Logger.info("Server disconnected!", "connection")
	
	return_to_title()
	_error_window.set_content("Connection to server lost! The server might be down, please try again.")
	_error_window.show()



func _on_connection_failed():
	_btn_cancel_online.hide()
	_btn_cancel_local.hide()
	_toggle_enabled_start_menu_buttons(true)


func _on_play_tutorial() -> void:
	_start_menu_buttons.hide()
	_tutorial.show()


func _on_play_online() -> void:
	_btn_cancel_online.show()
	_toggle_enabled_start_menu_buttons(false)
	Server.connect_to_server(REMOTE_SERVER_IP)


func _on_cancel_online() -> void:
	_btn_cancel_online.hide()
	_toggle_enabled_start_menu_buttons(true)
	Server.disconnect_from_server(true)
	return_to_title()


func _on_play_local() -> void:
	_btn_cancel_local.show()
	_toggle_enabled_start_menu_buttons(false)
	Server.connect_to_server(_lineEdit_local_ip.text)


func _on_cancel_local() -> void:
	_btn_cancel_local.hide()
	_toggle_enabled_start_menu_buttons(true)
	Server.disconnect_from_server(true)
	return_to_title()


func _on_open_settings() -> void:	
	_settings.show()


func _on_exit() -> void:
	get_tree().quit()


func _on_search_create_game_room_pressed() -> void:
	# just create room with default naming
	# 	otherwise would need virtual keyboard vor controller support
	#_game_room_creation.show()
	_on_creation_create_game_room_pressed("GameRoom")


func _on_creation_create_game_room_pressed(game_room_name) -> void:
	Server.send_create_game_room(game_room_name)


func _on_search_back_pressed() -> void:
	_start_menu_buttons.show()
	Server.disconnect_from_server(true)
	return_to_title()


func _on_creation_back_pressed() -> void:
	_game_room_search.show()


func _on_join_game_room_pressed() -> void:
	var selected_room = _game_room_search.get_selected_game_room()
	if selected_room != -1:
		Server.send_join_game_room(selected_room, _player_user_name)


func _on_room_search_visibility_changed() -> void:
	_btn_play_tutorial.grab_focus()


func _on_error_window_visibility_changed() -> void:
	if not _error_window.visible:
		if _game_room_lobby.visible:
			_game_room_lobby.grab_ready_button_focus()
		else:
			_btn_play_tutorial.grab_focus()


func _on_game_room_leave_pressed() -> void:
	_in_game_room = false
	_game_room_search.show()


func _on_game_room_created(game_room_id, game_room_name) -> void:
	_game_room_search.add_game_room(game_room_id, game_room_name)
	_game_room_creation.hide()

	Server.send_join_game_room(game_room_id, _player_user_name)


func _on_game_rooms_received(game_room_dic) -> void:
	_game_room_search.set_game_rooms(game_room_dic)


func _on_game_room_joined(player_id_name_dic, game_room_id):
	_game_room_lobby.set_players(player_id_name_dic, _player_rpc_id)
	
	if _in_game_room:
		return

	_in_game_room = true
	
	Server.send_get_game_room_owner()
	
	_game_room_creation.hide()
	_game_room_search.hide()
	_game_room_lobby.show()
	_game_room_lobby.init(game_room_id, _game_room_search.get_game_room_name(game_room_id))


func _on_game_room_ready_received(player_id):
	if player_id == _player_rpc_id:
		_game_room_lobby.toggle_ready_button(true)
	_game_room_lobby.set_player_ready(player_id, true)


func _on_game_room_not_ready_received(player_id):
	if player_id == _player_rpc_id:
		_game_room_lobby.toggle_ready_button(false)
	_game_room_lobby.set_player_ready(player_id, false)


func _enter_game():
	_in_game = true
	$MenuMusic.stop()


func _exit_game():
	_in_game = false
	$MenuMusic.play()


func _on_load_level_received():
	_enter_game()
	$CenterContainer.hide()
	_world = world_scene.instance()
	var level = Constants.level_scenes[_game_room_lobby.selected_level_index].instance()
	level.capture_point_scene = capture_point_scene
	add_child(_world)
	level.spawn_point_scene = spawn_point_scene
	_world.set_level(level)
	_world.add_child(level)
	_world.level_set_up_done()
	_game_room_lobby.reset_players()


func _on_tutorial_scenario_started() -> void:
	_enter_game()


func _on_tutorial_scenario_completed() -> void:
	_exit_game()
	_tutorial.show()


func _on_tutorial_back_pressed() -> void:
	_tutorial.hide()
	_start_menu_buttons.show()
	_btn_play_tutorial.grab_focus()


func _on_gameplay_menu_resume_pressed() -> void:
	_toggle_player_input_pause(false)


func _on_gameplay_menu_leave_pressed() -> void:
	if not _in_game:
		return
	
	if _world != null:
		Server.send_leave_game()
	else:
		assert(_tutorial._scenario != null)
		_tutorial.stop_scenario()
	
	_exit_game()


func _toggle_player_input_pause(value: bool) -> void:
	if not _in_game:
		return
	
	if _world != null:
		_world.toggle_player_input_pause(value)
	else:
		_tutorial.toggle_player_input_pause(value)


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == BUTTON_LEFT \
	and event.is_pressed():
		var _ret = OS.shell_open("https://github.com/lizrad/recursio")


func _on_player_left_game(player_id) -> void:
	return_to_game_room_lobby()
	# Other player left
	if player_id != _player_rpc_id:
		_error_window.set_content("Opponent left the game! The game will automatically be exited if one player leaves the game.")
		_error_window.show()


func _on_player_disconnected(player_id) -> void:
	return_to_game_room_lobby()
	# Other player left
	if player_id != _player_rpc_id:
		_error_window.set_content("Opponent disconnected! The game will be terminated.")
		_error_window.show()


func _on_game_room_owner_received(player_id) -> void:
	if _game_room_lobby.visible:
		_game_room_lobby.set_is_owner(player_id == _player_rpc_id)


func _on_level_selected_received(level_index) -> void:
	_game_room_lobby.set_selected_level(level_index)
	_game_room_lobby.enable_ready_button()


func _on_fog_of_war_toggled(is_fog_of_war_enabled) -> void:
	_game_room_lobby.set_fog_of_war(is_fog_of_war_enabled)
	_game_room_lobby.enable_ready_button()
	
