extends Node

export(float) var inner_deadzone := 0.3
export(float) var outer_deadzone := 0.7
export(float) var rotate_threshold := 0.0

onready var _player: Player = get_parent().get_parent()


var block_movement: bool = false
var block_swapping: bool = false
var disabled_inputs: Dictionary = {
	"player_shoot": false,
	"player_melee": false,
	"player_dash": false
}

# Maps the actual button to the internal enums
var _trigger_dic : Dictionary = {
	"player_shoot": ActionManager.Trigger.FIRE_START,
	"player_melee": ActionManager.Trigger.DEFAULT_ATTACK_START,
	"player_dash": ActionManager.Trigger.SPECIAL_MOVEMENT_START
}
var _action_manager
var _player_initialized: bool = false

func _ready():
	var _error = _player.connect("initialized", self, "_on_player_initialized")
	_error = _player.connect("timeline_index_changed", self, "_swap_weapon_type")


func _physics_process(_delta):
	if not _player_initialized:
		return

	var cur_phase = _player.get_round_manager().get_current_phase()
	if cur_phase == RoundManager.Phases.GAME:
		var movement_vector = Vector3.ZERO
		if not block_movement:
			var input = DeadZones.apply_2D(_get_input("player_move"), inner_deadzone, outer_deadzone)
			movement_vector = Vector3(input.y, 0.0, -input.x)
		InputManager.add_movement_to_input_frame(movement_vector)
		
		var rotate_vector = Vector3.ZERO
		if not block_movement:
			var rotate_input = DeadZones.apply_2D(_get_input("player_look"), 0.1, 1)
			rotate_vector = Vector3(rotate_input.y, 0.0, -rotate_input.x)
			if InputManager.get_current_controller() == "keyboard" and rotate_vector == Vector3.ZERO:
				var mouse_rotation = _get_rotation_from_mouse()
				rotate_vector = Vector3(mouse_rotation.x, 0.0, mouse_rotation.y)
		InputManager.add_rotation_to_input_frame(rotate_vector)

		var buttons_pressed: int = _get_buttons_pressed()
		# invert pressed buttons for shooting here
		# to delay ghosts triggering actions to button_released
		if buttons_pressed & ActionManager.Trigger.FIRE_START:
			_player.aim_mode = true
			buttons_pressed &= ~(ActionManager.Trigger.FIRE_START)
		elif _player.aim_mode == true:
			_player.aim_mode = false
			buttons_pressed |= ActionManager.Trigger.FIRE_START

		_player.apply_input(movement_vector, rotate_vector, buttons_pressed)
		InputManager.set_triggers_in_input_frame(buttons_pressed)
		InputManager.close_current_input_frame()
		InputManager.send_player_input_data_to_server()
	elif cur_phase == RoundManager.Phases.PREPARATION && not block_swapping:
		if Input.is_action_just_pressed("player_switch"):
			_select_timeline(true)
		elif Input.is_action_just_pressed("player_switch_prev"):
			_select_timeline(false)
		elif Input.is_action_pressed("ui_accept"):
			_player._button_overlay_simple.set_active(false)
			Server.send_player_ready()


func _select_timeline(mode: bool):
	var count = Constants.get_value("ghosts", "max_amount")
	var timeline_index: int = (_player.timeline_index + (1 if mode else count)) % (count + 1)
	_player.timeline_index = timeline_index


func _on_player_initialized():
	_action_manager = _player.get_action_manager()
	_player_initialized = true


# Changes the weapon depending on the given timeline index
func _swap_weapon_type(timeline_index) -> void:
	var max_ammo = _action_manager.get_max_ammo_for_trigger(ActionManager.Trigger.FIRE_START, timeline_index)
	var img_bullet = _action_manager.get_img_bullet_for_trigger(ActionManager.Trigger.FIRE_START, timeline_index)
	var wall_index = Constants.get_value("ghosts", "wall_placing_timeline_index")
	var accent_type = "primary" if wall_index != timeline_index else "secondary"
	var color_name = "player_" + accent_type + "_accent"

	_player.activate_spawn_point_hud(timeline_index)
	_player.update_weapon_type_hud(max_ammo, img_bullet, color_name)


func _get_rotation_from_mouse() -> Vector2:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var player_pos: Vector2 = _player.get_camera().unproject_position(_player.get_body().global_transform.origin)
	var rotation_vector = (mouse_pos-player_pos).normalized()
	return rotation_vector
	
	
# Reads the input of the given type e.g. "player_move" or "player_look"
func _get_input(type) -> Vector2:
	return Vector2(
		Input.get_action_strength(type + "_up") - Input.get_action_strength(type + "_down"),
		Input.get_action_strength(type + "_right") - Input.get_action_strength(type + "_left")
	)


# Returns a binary representation of all buttons pressed
func _get_buttons_pressed() -> int:
	var buttons := 0
	for trigger in _trigger_dic:
		if not disabled_inputs[trigger]:
			if Input.is_action_pressed(trigger):
				buttons |= _trigger_dic[trigger]

	return buttons
