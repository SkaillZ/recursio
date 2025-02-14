extends Node
class_name GameManager


onready var _round_manager: RoundManager = get_node("../RoundManager")


# These are optional
var _game_end_screen
var _countdown_screen

var _level: Level
var _player: Player
var _enemy: Enemy

var _player_kills: Array = [0,0]
var _player_deaths: Array = [0,0]
var _ghost_kills: Array = [0,0]
var _ghost_deaths: Array = [0,0]


func _ready() -> void:
	if has_node("../../GameEndScreen"):
		_game_end_screen = get_node("../../GameEndScreen")
	
	if has_node("../../CountdownScreen"):
		_countdown_screen = get_node("../../CountdownScreen")
	
	var _error = _round_manager.connect("game_phase_started", self, "_on_game_phase_started") 
	_error = _round_manager.connect("countdown_phase_started", self, "_on_countdown_phase_started")
	
	_error = Server.connect("game_result", self, "_on_game_result")
	
	_error = Server.connect("ghost_hit", self, "_on_ghost_hit") 
	_error = Server.connect("quiet_ghost_hit", self, "_on_ghost_hit") 
	_error = Server.connect("player_hit", self, "_on_player_hit") 
	
	_error = Server.connect("capture_point_captured", self, "_on_capture_point_captured") 
	_error = Server.connect("capture_point_team_changed", self, "_on_capture_point_team_changed") 
	_error = Server.connect("capture_point_status_changed", self, "_on_capture_point_status_changed") 
	_error = Server.connect("capture_point_capture_lost", self, "_on_capture_point_capture_lost") 


func set_player(player: Player)  -> void:
	_player = player
	_level.show_spawn_point_weapon_type(_player.team_id)
	_level.set_team_id(_player.team_id)


func set_enemy(enemy: Enemy)  -> void:
	_enemy = enemy


func set_level(level: Level)  -> void:
	_level = level


func get_spawn_points(team_id) -> Array:
	return _level.get_spawn_points(team_id)


func get_spawn_point(team_id: int, timeline_index: int) -> Node:
	return get_spawn_points(team_id)[timeline_index]


func get_capture_points() -> Array:
	return _level.get_capture_points()


func toggle_spawn_points(toggle: bool) -> void:
	_level.toggle_spawn_points(toggle)


func toggle_capture_points(toggle: bool) -> void:
	_level.toggle_capture_points(toggle)


func reset_level() -> void:
	# Reset level
	_level.reset()
	_level.toggle_capture_points(false)
	_level.toggle_spawn_points(true)


func _on_game_phase_started() -> void:
	if _countdown_screen:
		_countdown_screen.deactivate()


func _on_countdown_phase_started() -> void:
	if _countdown_screen:
		_countdown_screen.activate()


func _on_game_result(winning_player_index) -> void:
	_player.hide_hud()
	if _game_end_screen:
		_game_end_screen.set_stats(_player.team_id, _player_kills, _player_deaths, _ghost_kills, _ghost_deaths)
		_game_end_screen.show_stats()
		_game_end_screen.enable_room_button()
		_game_end_screen.enable_title_button()
		_game_end_screen.show()
	if winning_player_index == _player.player_id:
		Logger.info("Player won!", "gameplay")
		if _game_end_screen:
			_game_end_screen.set_panel_color("player_main")
			_game_end_screen.set_title("You Won!")
	else:
		Logger.info("Player lost!", "gameplay")
		if _game_end_screen:
			_game_end_screen.set_panel_color("enemy_main")
			_game_end_screen.set_title("You Lost!")


func _on_player_hit(hit_data: HitData) -> void:
	if hit_data.victim_team_id == _player.team_id:
		_player_deaths[_player.team_id] += 1
	else:
		_player_deaths[_enemy.team_id] += 1
	_check_for_perpetrator(hit_data)


func _on_ghost_hit(hit_data: HitData) -> void:
	if hit_data.victim_team_id == _player.team_id:
		_ghost_deaths[_player.team_id] += 1
	else:
		_ghost_deaths[_enemy.team_id] += 1
	_check_for_perpetrator(hit_data)


func _check_for_perpetrator(hit_data: HitData) -> void:
	if hit_data.perpetrator_team_id == _player.team_id:
		if hit_data.perpetrator_timeline_index == _player.timeline_index:
			_player_kills[_player.team_id] += 1
		else:
			_ghost_kills[_player.team_id] += 1
	else:
		if hit_data.perpetrator_timeline_index == _enemy.timeline_index:
			_player_kills[_enemy.team_id] += 1
		else:
			_ghost_kills[_enemy.team_id] += 1


func _on_capture_point_captured(capturing_player_team_id: int, capture_point) -> void:
	_level.get_capture_points()[capture_point].apply_server_capture_gained(capturing_player_team_id)


func _on_capture_point_team_changed(capturing_player_team_id: int, capture_point) -> void:
	_level.get_capture_points()[capture_point].apply_server_capturer_switched(capturing_player_team_id)


func _on_capture_point_status_changed(capturing_player_team_id: int, capture_point: int, capture_progress: float) -> void:
	_level.get_capture_points()[capture_point].apply_server_capture_progress_changed(capturing_player_team_id, capture_progress)


func _on_capture_point_capture_lost(_capturing_player_team_id: int, capture_point: int) -> void:
	_level.get_capture_points()[capture_point].apply_server_capture_lost()

