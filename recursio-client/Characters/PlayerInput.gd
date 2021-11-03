extends Node

export(float) var inner_deadzone := 0.1
export(float) var outer_deadzone := 0.9
export(float) var rotate_threshold := 0.0

onready var _player: Player = get_parent().get_parent()


# Maps the actual button to the internal enums
var _trigger_dic : Dictionary = {
	"player_shoot": ActionManager.Trigger.FIRE_START,
	"player_melee": ActionManager.Trigger.DEFAULT_ATTACK_START,
	"player_dash": ActionManager.Trigger.SPECIAL_MOVEMENT_START
}

var _action_manager

var _player_timeline_pick_trigger : String = "player_switch"

var _player_initialized: bool = false

func _ready():
	_player.connect("initialized", self, "_on_player_initialized")
	_player.connect("timeline_index_changed", self, "_swap_weapon_type")


func _physics_process(delta):
	if not _player_initialized:
		return

	var cur_phase = _player.get_round_manager().get_current_phase()
	if cur_phase == RoundManager.Phases.GAME:
		var input = DeadZones.apply_2D(_get_input("player_move"), inner_deadzone, outer_deadzone)
		var movement_vector = Vector3(input.y, 0.0, -input.x)
		InputManager.add_movement_to_input_frame(movement_vector)

		var rotate_input = DeadZones.apply_2D(_get_input("player_look"), inner_deadzone, outer_deadzone)
		var rotate_vector = Vector3(rotate_input.y, 0.0, -rotate_input.x)
		InputManager.add_rotation_to_input_frame(rotate_vector)

		var buttons_pressed: int = _get_buttons_pressed()
		_player.apply_input(movement_vector, rotate_vector, buttons_pressed)
		InputManager.set_triggers_in_input_frame(buttons_pressed)

		InputManager.close_current_input_frame()
		InputManager.send_player_input_data_to_server()
	elif cur_phase == RoundManager.Phases.PREPARATION:
		if Input.is_action_just_pressed(_player_timeline_pick_trigger):
			var timeline_index: int = (_player.timeline_index + 1) % (Constants.get_value("ghosts","max_amount") + 1)
			_player.timeline_index = timeline_index


func _on_player_initialized():
	_action_manager = _player.get_action_manager()
	_player_initialized = true


# Changes the weapon depending on the given timeline index
func _swap_weapon_type(timeline_index) -> void:
	var max_ammo = _action_manager.get_max_ammo_for_trigger(ActionManager.Trigger.FIRE_START, timeline_index)
	var img_bullet_bg = _action_manager.get_img_bullet_bg_for_trigger(ActionManager.Trigger.FIRE_START, timeline_index)
	var img_bullet = _action_manager.get_img_bullet_for_trigger(ActionManager.Trigger.FIRE_START, timeline_index)
	_player.update_weapon_type_hud(max_ammo, img_bullet_bg, img_bullet)



# Reads the input of the given type e.g. "player_move" or "player_look"
func _get_input(type) -> Vector2:
	return Vector2(
		Input.get_action_strength(type + "_up") - Input.get_action_strength(type + "_down"),
		Input.get_action_strength(type + "_right") - Input.get_action_strength(type + "_left")
	)


# Returns a binary representation of all buttons pressed
func _get_buttons_pressed() -> int:
	var buttons : Bitmask = Bitmask.new(0)
	for trigger in _trigger_dic:
		var action = _trigger_dic[trigger]

		if Input.is_action_just_pressed(trigger):
			buttons.add(action)

	return buttons.mask
