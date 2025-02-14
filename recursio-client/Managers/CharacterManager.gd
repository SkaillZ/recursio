extends Node
class_name CharacterManager

signal game_started()

onready var _action_manager: ActionManager = get_node("ActionManager")
onready var _game_manager: GameManager = get_node("GameManager")
onready var _round_manager: RoundManager = get_node("RoundManager")
onready var _ghost_manager: GhostManager = get_node("GhostManager")
onready var _visibility_checker: VisibilityChecker = get_node("VisibilityChecker")


var enemy_is_server_driven: bool = true
var hide_player_button_overlay: bool = false


# Scenes for instanciating 
var _player_scene = preload("res://Characters/Player.tscn")
var _enemy_scene = preload("res://Characters/Enemy.tscn")

# Reference to player
var _player: Player
# Reference to enemy
var _enemy: Enemy

var _player_rpc_id: int

var _time_since_last_server_update = 0.0
var _time_since_last_world_state_update = 0.0

var _max_timelines = Constants.get_value("ghosts", "max_amount")

var _input_paused: bool = false
# Stores active inputs before pausing
var _pre_pause_trigger_toggle_values: Dictionary = {}
var _pre_pause_movement_toggle_value: bool = false
var _pre_pause_swapping_toggle_value: bool = false

func _ready():
	var _error = Server.connect("phase_switch_received", self, "_on_phase_switch_received") 
	_error = Server.connect("game_start_received", self, "_on_game_start_received") 

	_error = _round_manager.connect("preparation_phase_started", self, "_on_preparation_phase_started") 
	_error = _round_manager.connect("countdown_phase_started", self, "_on_countdown_phase_started") 
	_error = _round_manager.connect("game_phase_started", self, "_on_game_phase_started") 
	_error = _round_manager.connect("game_phase_stopped", self, "_on_game_phase_stopped") 

	# Connect to server signals
	_error = Server.connect("spawning_player", self, "_on_spawn_player") 
	_error = Server.connect("spawning_enemy", self, "_on_spawn_enemy") 
	
	# TODO: Probably should move this to the mediator class if we actually implement this at some point
	_error = Server.connect("player_ghost_record_received", _ghost_manager, "on_player_ghost_record_received") 
	_error = Server.connect("enemy_ghost_record_received", _ghost_manager, "on_enemy_ghost_record_received") 
	_error = Server.connect("ghost_hit", _ghost_manager, "on_ghost_hit_from_server") 
	_error = Server.connect("quiet_ghost_hit", _ghost_manager, "on_quiet_ghost_hit_from_server") 
	_error = _round_manager.connect("preparation_phase_started", _ghost_manager, "on_preparation_phase_started") 
	_error = _round_manager.connect("countdown_phase_started", _ghost_manager, "on_countdown_phase_started") 
	_error = _round_manager.connect("game_phase_started", _ghost_manager, "on_game_phase_started") 
	_error = _round_manager.connect("game_phase_stopped", _ghost_manager, "on_game_phase_stopped") 
	####################################################
	
	
	
	_error = Server.connect("world_state_received", self, "_on_world_state_received") 
	_error = Server.connect("player_hit", self, "_on_player_hit") 

	_error = Server.connect("timeline_picked", self, "_on_timeline_picked") 

	_error = Server.connect("capture_point_captured", self, "_on_capture_point_captured") 
	_error = Server.connect("capture_point_capture_lost", self, "_on_capture_point_capture_lost")
	

	_player_rpc_id = get_tree().get_network_unique_id()
	set_physics_process(false)

func _physics_process(delta):
	# Update CapturePoints in player HUD
	_player.update_capture_point_hud(_game_manager.get_capture_points())
	
	if _round_manager.get_current_phase() != RoundManager.Phases.GAME:
		return

	if enemy_is_server_driven and _enemy:
		_update_enemy(delta)


func set_level(level: Level):
	_game_manager.set_level(level)

func get_player_id() -> int:
	return _player_rpc_id


func toggle_swapping(value: bool) -> void:
	_pre_pause_swapping_toggle_value = value
	if not _input_paused:
		_player.toggle_swapping(value)


func get_swapping_toggle_value() -> bool:
	return _player.get_swapping_toggle_value()

func toggle_movement(value: bool) -> void:
	_pre_pause_movement_toggle_value = value
	if not _input_paused:
		_player.toggle_movement(value)

func get_movement_toggle_value() -> bool:
	return _player.get_movement_toggle_value()

func toggle_trigger(trigger, value: bool) -> void:
	_pre_pause_trigger_toggle_values[trigger] = value
	if not _input_paused:
		_player.toggle_trigger(trigger, value)
	

func get_trigger_toggle_value(trigger) -> bool:
	return _player.get_trigger_toggle_value(trigger)


func toggle_player_input_pause(value: bool) -> void:
	_input_paused = value;
	if value:
		_pre_pause_trigger_toggle_values[ActionManager.Trigger.FIRE_START] = _player.get_trigger_toggle_value(ActionManager.Trigger.FIRE_START)
		_pre_pause_trigger_toggle_values[ActionManager.Trigger.DEFAULT_ATTACK_START] = _player.get_trigger_toggle_value(ActionManager.Trigger.DEFAULT_ATTACK_START)
		_pre_pause_trigger_toggle_values[ActionManager.Trigger.SPECIAL_MOVEMENT_START] = _player.get_trigger_toggle_value(ActionManager.Trigger.SPECIAL_MOVEMENT_START)
	
		_pre_pause_movement_toggle_value = _player.get_movement_toggle_value()
		_pre_pause_swapping_toggle_value = _player.get_swapping_toggle_value()
		_player.toggle_trigger(ActionManager.Trigger.FIRE_START, false)
		_player.toggle_trigger(ActionManager.Trigger.DEFAULT_ATTACK_START, false)
		_player.toggle_trigger(ActionManager.Trigger.SPECIAL_MOVEMENT_START, false)
		_player.toggle_movement(false)
		_player.toggle_swapping(false)
	else:
		_player.toggle_trigger(ActionManager.Trigger.FIRE_START, _pre_pause_trigger_toggle_values[ActionManager.Trigger.FIRE_START])
		_player.toggle_trigger(ActionManager.Trigger.DEFAULT_ATTACK_START, _pre_pause_trigger_toggle_values[ActionManager.Trigger.DEFAULT_ATTACK_START])
		_player.toggle_trigger(ActionManager.Trigger.SPECIAL_MOVEMENT_START, _pre_pause_trigger_toggle_values[ActionManager.Trigger.SPECIAL_MOVEMENT_START])
	
		_player.toggle_movement(_pre_pause_movement_toggle_value)
		_player.toggle_swapping(_pre_pause_swapping_toggle_value)


func _on_game_start_received(start_time):
	_round_manager.future_start_game(start_time)
	_ghost_manager.init(_game_manager,_round_manager, _action_manager, self)

func get_player() -> Player:
	return _player

func get_enemy() -> Enemy:
	return _enemy

func _on_phase_switch_received(round_index, next_phase, switch_time):
	_round_manager.round_index = round_index
	_round_manager.future_switch_to_phase(next_phase, switch_time)

func _on_preparation_phase_started() -> void:
	_player.toggle_movement(false)
	_player.reset_aim_mode()
	_player.clear_walls()
	_player.clear_past_frames()
	_player.reset_record_data()
	_player.move_to_spawn_point()
	_player.toggle_animation(false)
	_enemy.toggle_animation(false)

	_toggle_visbility_lights(false)
	_action_manager.clear_action_instances()
	if not hide_player_button_overlay:
		_player.show_button_overlay()
	
	_player.show_preparation_hud(_round_manager.round_index)
	
	# Show player whole level
	_player.move_camera_to_overview()
	
	# Move player to next timeline spawn point
	var next_timeline_index = min(_round_manager.round_index, _max_timelines)
	_enemy.timeline_index = next_timeline_index
	_player.timeline_index = next_timeline_index
	_player.round_index = _round_manager.round_index
	_enemy.round_index = _round_manager.round_index
	_enemy.spawn_point = _game_manager.get_spawn_point(_enemy.team_id, _enemy.timeline_index).global_transform.origin
	_enemy.move_to_spawn_point()
	_visibility_checker.reset()
	_game_manager.reset_level()

func _on_countdown_phase_started() -> void:
	_game_manager.toggle_spawn_points(false)
	_player.toggle_animation(true)
	_enemy.toggle_animation(true)
	_player.follow_camera()
	_player.show_countdown_hud()
	

func _on_game_phase_started() -> void:
	_player.set_record_data_timestamp(Server.get_server_time())
	_enemy.set_record_data_timestamp(Server.get_server_time())
	_player.toggle_movement(true)
	_player.set_overview_light_enabled(false)
	_toggle_visbility_lights(true)
	_player.show_game_hud(_round_manager.round_index)
	_game_manager.toggle_capture_points(true)

func _on_game_phase_stopped() -> void:
	_game_manager.toggle_capture_points(false)




func _on_player_timeline_changed(timeline_index) -> void:
	_player.spawn_point = _game_manager.get_spawn_point(_player.team_id, timeline_index).global_transform.origin
	_player.move_to_spawn_point()
	_ghost_manager.refresh_active_ghosts()
	_ghost_manager.refresh_path_select()
	
	# Client driven timeline changes are only allowed during prep phase, 
	# so we catch any race condition triggered changes outside the prep phase here
	# (Should not happen if latency and lag is minimal)
	if _round_manager.get_current_phase() == RoundManager.Phases.PREPARATION:
	# Send currently selected timeline to server
		if Server.is_connection_active:
			Server.send_timeline_pick(_player.timeline_index)

func _on_enemy_timeline_changed(timeline_index) -> void:
	_enemy.spawn_point = _game_manager.get_spawn_point(_enemy.team_id, timeline_index).global_transform.origin
	_enemy.move_to_spawn_point()
	_ghost_manager.refresh_active_ghosts()
	_ghost_manager.refresh_path_select()

func _on_timeline_picked(picking_player_id, timeline_index):
	var character = _player 
	if _player.player_id != picking_player_id:
		 character = _enemy
	character.timeline_index = timeline_index
	_ghost_manager.refresh_active_ghosts()
	_ghost_manager.refresh_path_select()
	
	_visibility_checker.set_player(_player)
	_visibility_checker.set_enemies(_enemy, _ghost_manager._enemy_ghosts)


func _on_spawn_player(player_id, spawn_point, team_id):
	set_physics_process(true)
	_player = _spawn_character(_player_scene, spawn_point, team_id)
	_player.player_init(_action_manager, _round_manager)
	_player.set_overview_light_enabled(false)
	_player_rpc_id = player_id
	_player.player_id = player_id
	_player.set_name(str(player_id))
	_player.toggle_animation(false)
	# Apply visibility mask to all entities which have been here before the player
	_apply_visibility_always(_player)
	if _enemy: 
		_apply_visibility_mask(_enemy)
	
	# Initialize capture point HUD for current level
	_player.setup_capture_point_hud(_game_manager.get_capture_points().size())
	

	# Initialize spawn points for current level
	_player.setup_spawn_point_hud(_game_manager.get_spawn_points(team_id))
	
	_game_manager.set_player(_player)
	var _error = _player.connect("timeline_index_changed", self, "_on_player_timeline_changed") 

	_error = Server.connect("wall_spawn", _player, "_on_wall_spawn_received") 
	
	emit_signal("game_started")

func _on_spawn_enemy(enemy_id, spawn_point, team_id):
	_enemy = _spawn_character(_enemy_scene, spawn_point, team_id)
	_enemy.player_id = enemy_id
	_enemy.enemy_init(_action_manager)
	_enemy.set_name(str(enemy_id))
	_enemy.toggle_animation(false)
	_apply_visibility_mask(_enemy)
	_game_manager.set_enemy(_enemy)
	var _error = _enemy.connect("timeline_index_changed", self, "_on_enemy_timeline_changed") 


func _on_world_state_received(world_state: WorldState):
	if _time_since_last_world_state_update < world_state.timestamp:
		_time_since_last_world_state_update = world_state.timestamp
		_time_since_last_server_update = 0

		if not _player: 
			return

		var player_states: Dictionary = world_state.player_states
		if player_states.has(_player_rpc_id):
			var server_player: PlayerState = player_states[_player_rpc_id]
			_player.handle_server_update(server_player.position, server_player.timestamp)
			var _success = player_states.erase(_player_rpc_id)

		for id in player_states:
			# Handle own player
			if id == _player_rpc_id:
				var server_player: PlayerState = player_states[_player_rpc_id]
				_player.handle_server_update(server_player.position, server_player.timestamp)
				var _success = player_states.erase(_player_rpc_id)
			else:
				# Set parameters for interpolation
				_enemy.last_position = _enemy.position
				_enemy.last_velocity = _enemy.velocity
				_enemy.rotation_y = player_states[id].rotation_y
				_enemy.server_position = player_states[id].position
				_enemy.server_velocity = player_states[id].velocity
				_enemy.server_acceleration = player_states[id].acceleration
				_enemy.last_triggers |= player_states[id].buttons

func _on_player_hit(hit_data: HitData) -> void:
	if hit_data.victim_team_id == _player.team_id:
		_player.server_hit(hit_data) 
	else:
		_enemy.server_hit(hit_data)

func _on_capture_point_captured(capturing_player_team_id, _capture_point):
	if capturing_player_team_id == _player.team_id:
		_player.move_camera_to_overview()
		_player.set_overview_light_enabled(true)

func _on_capture_point_capture_lost(capturing_player_team_id, _capture_point):
	if capturing_player_team_id == _player.team_id:
		if _round_manager.get_current_phase() == RoundManager.Phases.GAME:
			_player.follow_camera()
		_player.set_overview_light_enabled(false)

func _spawn_character(character_scene, spawn_point, team_id):
	var character: CharacterBase = character_scene.instance()
	add_child(character)
	character.spawn_point = spawn_point
	character.team_id = team_id
	character.move_to_spawn_point()
	return character

func _toggle_visbility_lights(value: bool):
	_player.toggle_visibility_light(value)

func _apply_visibility_mask(character) -> void:
	if not _player:
		return
	if Constants.fog_of_war_enabled:
		character.get_node("KinematicBody/CharacterModel").set_shader_param("always_draw", false)
		character.get_node("KinematicBody/CharacterModel").set_shader_param("visibility_mask", _player.get_visibility_mask())
		if character.has_node("KinematicBody/MiniMapIcon"):
			character.get_node("KinematicBody/MiniMapIcon").visibility_mask = _player.get_visibility_mask()
	else:
		_apply_visibility_always(character)

func _apply_visibility_always(character) -> void:
	character.get_node("KinematicBody/CharacterModel").set_shader_param("always_draw", true)

func team_id_to_player_id(team_id):
	if _player.team_id == team_id:
			return _player.player_id
	if _enemy.team_id == team_id:
		return _enemy.player_id
	return -1


func _update_enemy(delta) -> void:
	_time_since_last_server_update += delta
	var server_delta = 1.0 / Server.tickrate

	# Goes from 0 to 1 for each network tick
	var tick_progress = _time_since_last_server_update / server_delta
	tick_progress = min(tick_progress, 1)

	# TODO: Use base move function?
	_enemy.velocity = (
		_enemy.last_velocity
		+ (_enemy.server_velocity - _enemy.last_velocity) * tick_progress
	)

	var projected_from_start = (
		_enemy.last_position
		+ _enemy.velocity * _time_since_last_server_update
		+ (
			_enemy.server_acceleration
			* 0.5
			* _time_since_last_server_update
			* _time_since_last_server_update
		)
	)

	var projected_from_last_known = (
		_enemy.server_position
		+ _enemy.server_velocity * _time_since_last_server_update
		+ (
			_enemy.server_acceleration
			* 0.5
			* _time_since_last_server_update
			* _time_since_last_server_update
		)
	)

	_enemy.position = (
		projected_from_start
		+ (projected_from_last_known - projected_from_start) * tick_progress
	)

	_enemy.trigger_actions(_enemy.last_triggers)
	_enemy.last_triggers = 0

