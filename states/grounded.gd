extends State
class_name GroundState

var terrain_interactions: TerrainInteractions
var state_name = "grounded"
	
func update(character: Character, delta: float) -> void:	
	if character.input_forward:
		self.accelerate(character, delta)
	elif character.input_backward:
		self.decelerate(character, delta)
	else:
		self.tend_speed_to_zero(character, delta)

	self.steering(character, delta)

func on_trigger(character: Character, trigger: int) -> State:
	match trigger:
		Triggers.Actions.JUMP:
			if terrain_interactions.is_grounded(character):
				return ManualJumpState.new()
	return null

func accelerate(character: Character, delta: float) -> void:
	var hvel = HelperFunctions.get_hvel(character)
	var forward = HelperFunctions.get_forward_direction(character)
	# project hvel onto that forward axis to get current forward speed
	var curr_fwd_spd = forward.dot(hvel)

	# ask the helper how much to change speed this frame
	var delta_fwd = HelperFunctions.calc_forward_accel_delta(character, curr_fwd_spd, delta)

	character.velocity += forward * delta_fwd

# backward acceleration
var _deceleration_rate := 10.0
var _top_reverse_speed := 7.5

# could decompose this think about reuablility in drift for this and accel
func decelerate(character: Character, delta: float) -> void:
	var forward_direction = HelperFunctions.get_forward_direction(character)
	var hvel = HelperFunctions.get_hvel(character) 
	var curr_spd = hvel.length()
	var signed_spd = hvel.dot(forward_direction)  # +ve → forward, -ve → backward

	if signed_spd > 0.0:
		# brake toward zero
		var decel = min(_deceleration_rate * delta, signed_spd)
		character.velocity += -forward_direction * decel
	else:
		# creeping backward, but clamp to top_reverse_speed
		var rev_spd = abs(signed_spd)
		if rev_spd < _top_reverse_speed:
			# only add as much reverse accel as will keep ≤ cap
			var headroom = _top_reverse_speed - rev_spd
			var add = min(_deceleration_rate  * delta, headroom)
			character.velocity += forward_direction * -add
		
func tend_speed_to_zero(character: Character, delta: float) -> void:
	var forward_direction = HelperFunctions.get_forward_direction(character)
	var horizontal_velocity := HelperFunctions.get_hvel(character)
	var curr_spd = horizontal_velocity.length()
	var signed_spd = horizontal_velocity.dot(forward_direction)
	
	if signed_spd > 0.0:
		var speed_frac = clamp(curr_spd / character.top_speed, 0.0, 1.0)
		var decel = _deceleration_rate * speed_frac * delta
		decel = min(decel, curr_spd)
		var drag_dir = -horizontal_velocity.normalized()
		character.velocity += drag_dir * decel
	else:
		# return towards 0 if vehicle is reversing below 0 and no input
		var speed_frac = clamp(abs(signed_spd)/ _top_reverse_speed, 0.0, 1.0)
		var decel = _deceleration_rate  * speed_frac * delta
		decel = min(decel, abs(signed_spd))
		var drag_dir = -horizontal_velocity.normalized()
		character.velocity += drag_dir * decel
		
# turn settings
var _max_turn_rate := 1.5
var _turn_acceleration := 50.0
var _turn_curve_exponent := 2.0
var _turn_damping := 10.0
var _turn_velocity := 0.0
		
func steering(character: Character, delta: float) -> void:
	# base fractions
	var hspeed = HelperFunctions.get_hvel(character).length()
	var speed_frac= clamp(hspeed / character.top_speed, 0.0, 1.0)

	# min‐floor + sqrt ramp over first 40%
	var raw       = clamp(speed_frac / 0.8, 0.0, 1.0)
	var min_carve = 0.2
	var turn_scale= lerp(min_carve, 1.0, sqrt(raw)) #pow(raw, 2.0))

	# carve‐acceleration logic 
	var target_rate = character.input_turn * _max_turn_rate

	var turn_frac = abs(_turn_velocity) / _max_turn_rate
	turn_frac = clamp(turn_frac, 0.0, 1.0)
	var turn_accel_scale = 1.0 - pow(turn_frac, _turn_curve_exponent)

	if character.input_turn == 0.0:
		# bleed‐off
		_turn_velocity = lerp(_turn_velocity, 0.0, _turn_damping * delta)
	else:
		var rate_diff = target_rate - _turn_velocity
		var effective_scale = 1.0 if rate_diff * _turn_velocity < 0.0 else turn_accel_scale

		# angular accel scaled by speed
		var applied_accel = sign(rate_diff) \
			* _turn_acceleration \
			* effective_scale \
			* turn_scale
		_turn_velocity += applied_accel * delta

	_turn_velocity = clamp(_turn_velocity, -_max_turn_rate, _max_turn_rate)

	# carve body by a scaled amount
	var actual_turn = _turn_velocity * turn_scale * delta
	character.rotate_y(actual_turn)
	character.velocity = character.velocity.rotated(Vector3.UP, actual_turn)
