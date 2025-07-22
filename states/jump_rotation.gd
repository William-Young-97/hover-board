extends State
class_name JumpRotationState

var state_name = "jump_rotation"

var bank_target_yaw := 0.0
var bank_speed := 4.0 # radians/sec
const default_drift_angle := deg_to_rad(20)

func enter(character: Character, delta):
	pass

func exit(character: Character, delta: float):
	pass
	
func on_trigger(character: Character, trigger: int, delta: float):
	match trigger:
		Events.Trigger.LEFT:
			character.drift_dir = +1
			bank_target_yaw = character.base_jump_yaw \
							 + default_drift_angle * character.drift_dir
		Events.Trigger.RIGHT:
			character.drift_dir = -1
			bank_target_yaw = character.base_jump_yaw \
							 + default_drift_angle * character.drift_dir
		Events.Trigger.LANDED:
			if character.input_left:
				character.left_drift = true
				return DriftState.new()
			elif character.input_right:
				character.right_drift = true
				return DriftState.new()
			else:
				return GroundState.new()
	return null
			
func update(character: Character, delta: float) -> State:
	var old_yaw = character.rotation.y
	# move_toward prevents overshoot
	var new_yaw = HelperFunctions.step_angle( old_yaw,
		bank_target_yaw,
		bank_speed * delta
	)
	var yaw_delta = new_yaw - old_yaw
	character.rotation.y = new_yaw
	return null
