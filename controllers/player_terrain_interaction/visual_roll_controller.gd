extends Node
class_name VisualRollController

# TODO
# When travelling bacckwards the tilt needs to flipped to make sense
# implement roll for terrain orientation that runs spereately
# switch my collider to a flat capsual to lower ambiguity between model aand view states


@export var board_model_path: NodePath
@onready var _board_model: Node3D =  get_node(board_model_path)

@export var player_path: NodePath
@onready var _player: Character = get_node(player_path)

@export var steer_roll_deg := 0.3     # small roll when steering on ground
@export var bank_roll_deg  := 0.8    # deeper roll when drifting
@export var bank_roll_time := 0.3       # seconds to lerp into full bank roll
@export var return_time    := 0.5     # seconds to lerp back to flat

var _target_roll := 0.0
var _current_roll := 0.0

func _process(delta):
	# 1) decide target roll based on state + inputs
	match _player.current_state.state_name:
		"grounded":
			_target_roll = _player.input_turn * deg_to_rad(steer_roll_deg)
		"jump_rotation":
			_target_roll = 0.0
			# import jump_rotation
			_target_roll = _player.drift_dir * deg_to_rad(steer_roll_deg)
		"drifting":
			# import drift class
			_target_roll = _player.drift_dir * deg_to_rad(bank_roll_deg)
		_:
			_target_roll = 0.0

	# pick a speed to move toward target: faster when tipping in, slower when returning
	var in_speed  = 1.0 / bank_roll_time
	var out_speed = 1.0 / return_time
	var speed = in_speed if abs(_target_roll) > abs(_current_roll) else out_speed

	# roll toward target
	_current_roll = lerp(_current_roll, _target_roll, clamp(speed * delta, 0.0, 1.0))

	_board_model.rotation.x = 0
	_board_model.rotation.y = 0
	_board_model.rotation.z = rad_to_deg(_current_roll)
