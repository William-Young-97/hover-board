extends State
class_name JumpRotatationState

var terrain_interactions: TerrainInteractions
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


func update(character: Character, delta: float) -> State:
	var old_yaw = character.rotation.y
	# move_toward prevents overshoot
	var new_yaw = HelperFunctions.step_angle( old_yaw,
		bank_target_yaw,
		bank_speed * delta
	)
	var yaw_delta = new_yaw - old_yaw
	character.rotation.y = new_yaw
	
	# on landing pick next state.
	# this bool prevents us switchinig to quickly and losing the bank logic
	# neccessary to give time to the above code to complete and take us to our desired angle
	if terrain_interactions.is_grounded(character) and character.velocity.y <= 0.0:
		if character.input_drift_held:
			return DriftState.new()
		else:
			return GroundState.new()

	return null
