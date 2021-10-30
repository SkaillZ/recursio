extends PlayerBase
class_name Player

onready var _hud: HUD = get_node("HUD")

onready var _light_viewport = get_node("LightViewport")
onready var _overview_light = get_node("TransformReset/OverviewLight")
onready var _overview_target = get_node("TransformReset/OverviewTarget")
onready var _lerped_follow: LerpedFollow = get_node("TransformReset/LerpedFollow")
onready var _view_target = get_node("ViewTarget")

onready var _button_overlay: ButtonOverlay = get_node("ButtonOverlay")

var _past_frames = {}
var _just_corrected = false
var _last_server_position
var _last_server_time


func player_init(action_manager: ActionManager) -> void:
	.player_base_init(action_manager)


# OVERRIDE #
func reset() -> void:
	.reset()
	_hud.reset()


func get_visibility_mask():
	return _light_viewport.get_texture()


func set_overview_light_enabled(enabled):
	_overview_light.enabled = enabled


func move_camera_to_overview():
	_lerped_follow.target = _overview_target


func follow_camera():
	_lerped_follow.target = _view_target


func setup_capture_point_hud(number_of_capture_points) -> void:
	for i in number_of_capture_points:
		_hud.add_capture_point()
	_hud.set_player_id(self.team_id)


func update_weapon_type_hud(weapon_action: Action) -> void:
	_hud.update_ammo_type(weapon_action)


func update_fire_action_ammo_hud(amount: int) -> void:
	_hud.update_fire_action_ammo(amount)


func update_special_movement_ammo_hud(amount: int) -> void:
	_hud.update_special_movement_ammo(amount)


func update_capture_point_hud(capture_points: Array) -> void:
	var index: int = 0
	for capture_point in capture_points:
		_hud.update_capture_point(index, capture_point.get_capture_progress(), capture_point.get_capture_team())
		index += 1


func show_round_start_hud(round_index, latency) -> void:
	_hud.round_start(round_index, latency)


func show_latency_delay_hud() -> void:
	_hud.latency_delay_phase_start()


func show_preparation_hud(round_index: int) -> void:
	_hud.prep_phase_start(round_index)
	_button_overlay.show_buttons("ready", ButtonOverlay.BUTTONS.RIGHT, true)


func show_countdown_hud() -> void:
	_hud.countdown_phase_start()
	_button_overlay.hide_buttons()


func show_game_hud(round_index) -> void:
	_hud.game_phase_start(round_index)


func handle_server_update(position, time):
	_last_server_position = position
	_last_server_time = time

	#if not past_frames.has(time):
		# TODO: Need to handle this?
	#	return
	
	# Find the most fitting timestamp
	var time_with_data = time
	var closest_frame = null
	
	while not closest_frame:
		if _past_frames.has(time_with_data):
			closest_frame = _past_frames[time_with_data]
		else:
			time_with_data -= 1
		
		# Exit condition (e.g. for the first time)
		if time - time_with_data > 100:
			break
	
	if closest_frame:
		# Get value we had at that time
		var position_diff = position - closest_frame.position

		# If the difference is too large, correct it
		if position_diff.length() > 0.1:
			# TODO: Lerp there rather than setting it outright
			var before = .get_position()
			self.position += position_diff

			Logger.info(("Corrected from " + str(before) + " to " + str(.get_position())
				+ " (should be at " + str(position) + " according to server)"), "movement_validation")

			# Hotfix for overcompensation - we could also fix all following past states, but is that required?
			_past_frames.clear()

			_just_corrected = true

