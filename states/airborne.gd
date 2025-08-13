extends State
class_name AirborneState

var state_name = "airborne"

var hf: HelperFunctions
var _ah: AirborneHelper

var eligible_to_drift_left = false
var eligible_to_drift_right = false

var _input_turn := 0.0
const MIN_DRIFT_ENTRY_SPEED := 20

var bank_target_yaw := 0.0
var bank_speed := 4.0 # radians/sec
const default_drift_angle := deg_to_rad(30)


func enter(character: Character, delta):
	hf = HelperFunctions.new()
	_ah = AirborneHelper.new()
	
	character.air_base_entry_yaw = character.rotation.y
	print("Entering Airborne")
func update(character: Character, delta):
	character.move_and_slide()
	ti.apply_leveling_slerp(character, ti.grays, delta)
	
	ti.enforce_max_speed(character)
	ti.apply_gravity(delta, 2.2)
	# horrible input placement. Isolates steering from drift mechanic.
	if character.input_left:
		_input_turn = 1
	elif character.input_right:
		_input_turn = -1
	else:
		_input_turn = 0
	_ah.steer_airborne(character, _input_turn, delta)
		
	if self.eligible_to_drift_left == true or eligible_to_drift_right == true:
		self.pre_drift_air_bank(character, delta)
		
	
func on_trigger(character: Character, trigger: int, delta) -> State:
	match trigger:	
		Events.Trigger.JUMP_HELD:
			if character.jumped and character.input_left \
			and not self.eligible_to_drift_right \
			and hf.get_mph(character) > MIN_DRIFT_ENTRY_SPEED:
				character.drift_dir = +1
				bank_target_yaw = character.air_base_entry_yaw \
				 + default_drift_angle * character.drift_dir
				self.eligible_to_drift_left = true
				
			elif character.jumped and character.input_right \
			and not self.eligible_to_drift_left \
			and hf.get_mph(character) > MIN_DRIFT_ENTRY_SPEED:
				character.drift_dir = -1
				bank_target_yaw = character.air_base_entry_yaw \
				 + default_drift_angle * character.drift_dir
				self.eligible_to_drift_right = true
		
		Events.Trigger.LANDED:
			character.jumped = false
			if self.eligible_to_drift_left: 
				character.left_drift = true
				self.eligible_to_drift_left = false
				return DriftState.new()
			
			elif self.eligible_to_drift_right:
				character.right_drift = true
				self.eligible_to_drift_right = false
				return DriftState.new()
			else:
				return GroundState.new()
	return null

func pre_drift_air_bank(character: Character, delta: float):
	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n

	var old_yaw = character.rotation.y
	# move_toward prevents overshoot
	var new_yaw = hf.step_angle( old_yaw,
		bank_target_yaw,
		bank_speed * delta
	)
	var yaw_delta = new_yaw - old_yaw
	character.rotation.y = new_yaw
	
