extends "res://Players/CharacterBase.gd"

export(float) var inner_deadzone := 0.2
export(float) var outer_deadzone := 0.8
export(float) var rotate_threshold := 0.0


var drag := Constants.move_drag
var move_acceleration := Constants.move_acceleration
var velocity := Vector3.ZERO
var current_target_velocity := Vector3.ZERO
var _rotate_input_vector:= Vector3.ZERO

func get_normalized_input(type, outer_deadzone, inner_deadzone, min_length = 0.0):
	var input = Vector2(Input.get_action_strength(type + "_up") - 
						Input.get_action_strength(type + "_down"),
						Input.get_action_strength(type + "_right") - 
						Input.get_action_strength(type + "_left"))
	
	# Remove signs to reduce the number of cases
	var signs = Vector2(sign(input.x), sign(input.y))
	input = Vector2(abs(input.x), abs(input.y))
	
	if input.length() < min_length:
		return Vector2.ZERO
	
	# Deazones for each axis
	if input.x > outer_deadzone:
		input.x = 1.0
	elif input.x < inner_deadzone:
		input.x = 0.0
	else:
		input.x = inverse_lerp(inner_deadzone, outer_deadzone, input.x)
		
	if input.y > outer_deadzone:
		input.y = 1.0
	elif input.y < inner_deadzone:
		input.y = 0.0
	else:
		input.y = inverse_lerp(inner_deadzone, outer_deadzone, input.y)
		
	# Re-apply signs
	input *= signs
	
	# Limit at length 1
	if input.length() > 1.0:
		input /= input.length()
	
	return input

func _physics_process(delta):
	
	var input = get_normalized_input("player_move", outer_deadzone, inner_deadzone)
	var movement_input_vector = Vector3(input.y, 0.0, -input.x)
		
	var rotate_input = get_normalized_input("player_look", 1.0, 0.1)
	var rotate_input_vector = Vector3(rotate_input.y, 0.0, -rotate_input.x)
	if rotate_input_vector.distance_to(_rotate_input_vector) > rotate_threshold:
		if rotate_input_vector != Vector3.ZERO:
			_rotate_input_vector = rotate_input_vector
			look_at(rotate_input_vector + global_transform.origin, Vector3.UP)
		
	var move_direction_scale = (3.0 + movement_input_vector.dot(rotate_input_vector)) / 4.0 \
			if Constants.scale_movement_to_view_direction else 1.0

	apply_acceleration(movement_input_vector * move_acceleration * move_direction_scale)
		
	move_and_slide(velocity)
	transform.origin.y = 0

func apply_acceleration(acceleration):
	# First drag, then add the new acceleration
	# For drag: Lerp towards the target velocity
	# This is usually 0, unless we're on something that's moving, in which case it is that object's
	#  velocity
	velocity = lerp(velocity, current_target_velocity, drag)
	velocity += acceleration
