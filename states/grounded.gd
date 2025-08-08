extends State
class_name GroundState

var state_name = "grounded"
var _did_movement_input := false
var _input_turn := 0.0

const DRIFT_RETURN_ANGLE := deg_to_rad(20) 
const YAW_DURATION := 0.1
var _yaw_timer := 0.0
var _exit_drift_dir = 0

var exited_drift = false

func enter(character: Character, delta: float):
	print("Entering Grounded")
	vrc.board_roll_amount = 0.3
	character.connect("exited_drift", self._on_exited_drift)

func exit(character: Character, delta: float):
	character.left_drift = false
	character.right_drift = false

func _on_exited_drift():
	exited_drift = true
	_yaw_timer  = YAW_DURATION
	
func update(character: Character, delta: float) -> State:
	ti.enforce_max_speed(character)
	ti.apply_leveling_slerp(character, ti.grays, delta)
	ti.enforce_hover_floor(character, ti.grays, delta)
	ti.apply_gravity(delta)
	character.move_and_slide()
	# help align after exiting drift
	if self.exited_drift == true:
		if character.left_drift:
			self._exit_drift_dir = 1
		elif character.right_drift:
			self._exit_drift_dir = -1
		
		if self._yaw_timer <= 0.0:
			self._yaw_timer == 0
			self.exited_drift = false
		else:
			self._yaw_timer -= delta

		var fraction = delta / YAW_DURATION
		var target_ang = DRIFT_RETURN_ANGLE * self._exit_drift_dir
		var step_ang   = target_ang * fraction * -1  #
		
		var n = ti.get_ground_normal(ti.grays)
		if n.dot(Vector3.UP) < 0: n = -n
		var q = Quaternion(n, step_ang)
		var b = character.global_transform.basis
		character.global_transform.basis = (Basis(q) * b)
		
		ti.kill_lateral_velocity(character, delta, 0.1)
	else:
		ti.kill_lateral_velocity(character, delta)
	
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
			self.simple_steering(character, delta)
			self._input_turn = 0.0
		Events.Trigger.RIGHT:
			self._input_turn -= 1.0
			vrc.direction -= 1
			self.simple_steering(character, delta)
			self._input_turn = 0.0
		Events.Trigger.JUMP_PRESS:
			character.jumped = true
			self.jump(character)
			return AirborneState.new()
		Events.Trigger.AIRBORNE:
			return AirborneState.new()
	return null
	
const _jump_strength := 3
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
var _deceleration_rate := 25.0
var _top_reverse_speed := 25.0

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
var _max_turn_rate := 1.1
var _turn_acceleration := 25.0
var _turn_damping := sqrt(_turn_acceleration)
var _turn_velocity := 0.0

func simple_steering(character: Character, delta: float) -> void:
	var target_rate = self._input_turn * _max_turn_rate
	if self._input_turn == 0.0:
		_turn_velocity = lerp(_turn_velocity, 0.0, _turn_damping * delta)
	else:
		var rate_diff = target_rate - _turn_velocity
		var accel = sign(rate_diff) * _turn_acceleration * delta
		_turn_velocity += accel
	_turn_velocity = clamp(_turn_velocity, -_max_turn_rate, _max_turn_rate)
	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n
	var angle = _turn_velocity * delta
	# This works better on angle because both are inherently orthonormalised
	var q = Quaternion(n, angle)
	var b = character.global_transform.basis
	character.global_transform.basis = (Basis(q) * b)
