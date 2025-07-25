extends State
class_name GroundState

var state_name = "grounded"
var _did_movement_input := false
var _input_turn := 0.0
const ROLL_SPEED := deg_to_rad(45)
func enter(character: Character, delta:):
	print("Entering Grounded")
	vrc.board_roll_amount = 0.3

func update(character: Character, delta: float) -> State:
	ti.enforce_hover_floor(character, ti.grays)
	ti.apply_leveling_slerp(character, ti.grays, delta)
	ti.slide_on_slopes(character, ti.grays)
	character.move_and_slide()
	
	ti.clear_lateral_velocity(character)
	
	if not _did_movement_input:
		tend_speed_to_zero(character, delta)
	_did_movement_input = false
	return null
	
func on_trigger(character: Character, trigger: int, delta) -> State:
	match trigger:
		Events.Trigger.FORWARD:
			self.accelerate(character, delta)
			_did_movement_input = true
		Events.Trigger.BACKWARD:
			self.decelerate(character, delta)
			_did_movement_input = true
		Events.Trigger.LEFT:
			self._input_turn += 1.0
			vrc.direction += 1
			self.steering(character, delta)
			self._input_turn = 0.0
		Events.Trigger.RIGHT:
			self._input_turn -= 1.0
			vrc.direction -= 1
			self.steering(character, delta)
			self._input_turn = 0.0
		Events.Trigger.JUMP_PRESS:
			character.jumped = true
			self.jump(character)
			return AirborneState.new()
		Events.Trigger.AIRBORNE:
			return AirborneState.new()
	return null
	
const _jump_strength := 2
func jump(character: Character) -> void:
	# surface normal
	var n = ti.get_ground_normal(ti.grays)
	#  make sure it’s pointing up
	if n.dot(Vector3.UP) < 0:
		n = -n
	# apply  jump impulse along that normal
	character.velocity += n * _jump_strength
	

	
func accelerate(character: Character, delta: float) -> void:
	var forward = ti.get_forward_direction_relative_to_surface(character, ti.grays)
	# current speed along  forward
	var hvel = ti.get_hvel_relative_to_surface(character, ti.grays)
	var curr_fwd_spd = forward.dot(hvel)
	# Compute accel delta
	var delta_fwd = HelperFunctions.calc_forward_accel_delta(character, curr_fwd_spd, delta)

	character.velocity += forward * delta_fwd

# backward acceleration
var _deceleration_rate := 10.0
var _top_reverse_speed := 7.5

# could decompose this think about reuablility in drift for this and accel
func decelerate(character: Character, delta: float) -> void:
	var forward_direction = ti.get_forward_direction_relative_to_surface(character, ti.grays)
	var hvel = ti.get_hvel_relative_to_surface(character, ti.grays) 
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
	var forward_direction = ti.get_forward_direction_relative_to_surface(character, ti.grays)
	var horizontal_velocity = ti.get_hvel_relative_to_surface(character, ti.grays)
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
	var hspeed = ti.get_hvel_relative_to_surface(character, ti.grays).length()
	var speed_frac= clamp(hspeed / character.top_speed, 0.0, 1.0)

	# min‐floor + sqrt ramp over first 40%
	var raw       = clamp(speed_frac / 0.8, 0.0, 1.0)
	var min_carve = 0.2
	var turn_scale= lerp(min_carve, 1.0, sqrt(raw)) #pow(raw, 2.0))

	# carve‐acceleration logic 
	var target_rate = self._input_turn * _max_turn_rate

	var turn_frac = abs(_turn_velocity) / _max_turn_rate
	turn_frac = clamp(turn_frac, 0.0, 1.0)
	var turn_accel_scale = 1.0 - pow(turn_frac, _turn_curve_exponent)

	if self._input_turn == 0.0:
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

	# raw turn angle
	var actual_turn = _turn_velocity * turn_scale * delta

	# orient the surface normal upwards
	var n = ti.get_ground_normal( ti.grays)

	character.rotate_object_local(n, actual_turn)
	character.velocity = character.velocity.rotated(n, actual_turn)
