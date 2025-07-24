extends State
class_name AirborneState

var state_name = "airborne"

var eligible_to_drift = false

var _input_turn := 0.0
const MIN_DRIFT_ENTRY_SPEED := 20

var bank_target_yaw := 0.0
var bank_speed := 4.0 # radians/sec
const default_drift_angle := deg_to_rad(20)

var hf = HelperFunctions

func enter(character: Character, delta):
	character.air_base_entry_yaw = character.rotation.y
	print("Entering Airborne")
func update(character: Character, delta):
	_terrain_interactions.apply_leveling_slerp(character, _terrain_interactions.arays, delta)
	character.move_and_slide()
	if self.eligible_to_drift == true:
		self.pre_drift_air_bank(character, delta)
		# gravity
	_terrain_interactions.apply_gravity(delta)
	
func on_trigger(character: Character, trigger: int, delta) -> State:
	match trigger:	
		Events.Trigger.JUMP_HELD:			
			if character.jumped and character.input_left \
			and hf.get_mph(character) > MIN_DRIFT_ENTRY_SPEED:
				character.drift_dir = +1
				bank_target_yaw = character.air_base_entry_yaw \
				 + default_drift_angle * character.drift_dir
				
				character.jumped = false
				self.eligible_to_drift = true
			elif character.jumped and character.input_right \
			and hf.get_mph(character) > MIN_DRIFT_ENTRY_SPEED:
				character.drift_dir = -1
				bank_target_yaw = character.air_base_entry_yaw \
				 + default_drift_angle * character.drift_dir
				
				character.jumped = false
				self.eligible_to_drift = true
		
		Events.Trigger.LANDED:

			if character.input_left and self.eligible_to_drift:
				character.left_drift = true
				self.eligible_to_drift = false
				return DriftState.new()
			
			elif character.input_right and self.eligible_to_drift:
				character.right_drift = true
				self.eligible_to_drift = false
				return DriftState.new()
			else:
				return GroundState.new()
	return null

func pre_drift_air_bank(character: Character, delta: float):
	var old_yaw = character.rotation.y
	# move_toward prevents overshoot
	var new_yaw = hf.step_angle( old_yaw,
		bank_target_yaw,
		bank_speed * delta
	)
	var yaw_delta = new_yaw - old_yaw
	character.rotation.y = new_yaw
