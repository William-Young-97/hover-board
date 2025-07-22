extends Node
class_name VisualRollController

# TODO
# When travelling bacckwards the tilt needs to flipped to make sense
# implement roll for terrain orientation that runs spereately
# switch my collider to a flat capsual to lower ambiguity between model aand view states

@export var board_model_path: NodePath
@onready var _board_model: Node3D =  get_node(board_model_path)

@export var character_path: NodePath
@onready var _character: Character = get_node(character_path)

var _target_roll := 0.0
var _current_roll := 0.0

# updated in each state based on the visual roll required
var board_roll_amount := 0.5
var direction := 0.0

func _process(delta: float) -> void:
	visual_roll(delta)
	self.direction = 0.0
	
func visual_roll(delta: float) -> void:
	var bank_roll_time := 0.3
	var return_time    := 0.5
	
	_target_roll = self.direction * deg_to_rad(self.board_roll_amount)
	
	var in_speed  = 1.0 / bank_roll_time
	var out_speed = 1.0 / return_time
	var speed = in_speed if abs(_target_roll) > abs(_current_roll) else out_speed

	# roll toward target
	_current_roll = lerp(_current_roll, _target_roll, clamp(speed * delta, 0.0, 1.0))

	_board_model.rotation.x = 0
	_board_model.rotation.y = 0
	_board_model.rotation.z = rad_to_deg(_current_roll)
