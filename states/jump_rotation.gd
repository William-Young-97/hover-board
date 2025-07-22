extends State
class_name JumpRotatationState

var state_name = "jump_rotation"

var bank_target_yaw := 0.0
var bank_speed := 4.0 # radians/sec
const default_drift_angle := deg_to_rad(20)

func enter(character: Character, delta):
	if character.input_left:
		character.left_drift = true
		character.drift_dir += 1
	elif character.input_right:
		character.right_drift = true
		character.drift_dir -= 1
	else:
		character.drift_dir = 0
	
	# compute the absolute yaw to bank toward
	bank_target_yaw = character.base_jump_yaw \
	+ default_drift_angle * character.drift_dir

func on_trigger(character: Character, trigger: int, delta: float):
	# if input_drift_held and we have a dir we bank in air
	match trigger:
		Events.Trigger.START_DRIFT:
			return DriftState.new()
		Events.Trigger.LANDED:
			return GroundState.new()
			
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
