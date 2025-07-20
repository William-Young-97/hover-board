extends State
class_name JumpRotatationState

# no need for on trigger as this state is an end state of rotation
# relesaing drift is handled in the main input handler 

var state_name = "jump_rotation"

var drift_dir = 0
var bank_target_yaw := 0.0
var bank_speed := 4.0 # radians/sec
const default_drift_angle := deg_to_rad(30)

func enter(character: Character, delta):
	if character.input_left:
		character.left_drift = true
		drift_dir += 1
	elif character.input_right:
		character.right_drift = true
		drift_dir -= 1
	else:
		drift_dir = 0
	
	# compute the absolute yaw to bank toward
	bank_target_yaw = character.base_jump_yaw \
	+ default_drift_angle * drift_dir


func update(character: Character, delta: float) -> State:
	character.apply_character_gravity(delta)
	character.move_and_slide()
	character.apply_hover(delta)
	
	var old_yaw = character.rotation.y
	# move_toward prevents overshoot
	var new_yaw = character.step_angle( old_yaw,
		bank_target_yaw,
		bank_speed * delta
	)
	var yaw_delta = new_yaw - old_yaw
	character.rotation.y = new_yaw
	
	# on landing pick next state.
	# this bool prevents us switchinig to quickly and losing the bank logic
	# neccessary to give time to the above code to complete and take us to our desired angle
	if character.is_grounded() and character.velocity.y <= 0.0:
		if character.input_drift_held:
			return DriftingState.new()
		else:
			return GroundState.new()

	return null
