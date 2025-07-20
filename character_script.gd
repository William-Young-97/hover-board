extends CharacterBody3D
class_name Character

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# state and inputs exposed
var current_state : State = null
var input_forward    := false
var input_backward   := false
var input_left := false
var input_right := false
var input_boost      := false
var input_jump       := false
var input_drift_held     := false
var input_drift_release := false
var input_turn := 0.0
var _triggers := []

var base_jump_yaw = 0.0
var top_speed := 50.0  # used in acceleration; steering; hclamp; tend to zero
var left_drift = false
var right_drift = false

func _ready():
	current_state = GroundState.new()
	# if ever have an `enter()` callback (for groundstate), call it here

func _physics_process(delta: float) -> void:
	# DEBUGS
	#print(current_state.state_name)


	# print(Engine.get_frames_per_second())

	# CODE
	_triggers = _handle_inputs()
	# current_state react to each trigger
	for trigger in _triggers:
		var next_state = current_state.on_trigger(self, trigger)
		if next_state:
			current_state.exit(self, delta)
			current_state = next_state
			current_state.enter(self, delta)
			break    # only one trigger→state change per frame

	# do the per-frame work and catch any transition it requests
	var new_state = current_state.update(self, delta)
	if new_state:
		current_state.exit(self, delta)
		current_state = new_state
		current_state.enter(self, delta)
		
func _handle_inputs() -> Array:
	var _out := []
	input_forward  = Input.is_action_pressed("forward")
	input_backward = Input.is_action_pressed("back")
	input_left = Input.is_action_pressed("left")
	input_right = Input.is_action_pressed("right")
	input_jump = Input.is_action_just_pressed("jump_drift")
	input_drift_held  = Input.is_action_pressed("jump_drift")
	input_drift_release = Input.is_action_just_released("jump_drift")
	
	# gives steering input
	# works as we start in grounded and other states exit to grounded without triggers
	# reset to 0 each frame
	input_turn = 0.0
	if input_left :
		input_turn += 1.0
	if input_right:
		input_turn -= 1.0

	if input_jump:
		_out.append(Triggers.Actions.JUMP)
	
	# assuming jump is held AND state = jump (on trig only matches for jump state no other)
	# and we get a dir input we can start drift
	if input_drift_held and (input_left or input_right):
			_out.append(Triggers.Actions.START_DRIFT)

	if input_drift_release:
		_out.append(Triggers.Actions.END_DRIFT)

	return _out

func accelerate(delta: float) -> void:
	var hvel = Vector3(velocity.x, 0, velocity.z)
	var forward = get_forward_direction()
	forward.y = 0
	forward = forward.normalized()
	
	# project hvel onto that forward axis to get current forward speed
	var curr_fwd_spd = forward.dot(hvel)

	# ask the helper how much to change speed this frame
	var delta_fwd = calc_forward_accel_delta(curr_fwd_spd, delta)

	velocity += forward * delta_fwd

# forward acceleration
var _max_acceleration := 8.0


func calc_forward_accel_delta(curr_fwd_spd: float, delta: float) -> float:
	# how far along top speed we are
	var frac = clamp(curr_fwd_spd / top_speed, 0.0, 1.0)
	# quadratic taper: big accel at low speeds, zero at top
	var strength = _max_acceleration * (1.0 - frac * frac)
	return strength * delta

# backward acceleration
var _deceleration_rate := 10.0
var _top_reverse_speed := 7.5
		
func decelerate(delta: float) -> void:
	var forward_direction = get_forward_direction()
	forward_direction.y = 0
	forward_direction = forward_direction.normalized() 
	var hvel    = Vector3(velocity.x, 0, velocity.z)
	var curr_spd = hvel.length()
	var signed_spd = hvel.dot(forward_direction)  # +ve → forward, -ve → backward

	if signed_spd > 0.0:
		# brake toward zero
		var decel = min(_deceleration_rate * delta, signed_spd)
		velocity += -forward_direction * decel
	else:
		# creeping backward, but clamp to top_reverse_speed
		var rev_spd = abs(signed_spd)
		if rev_spd < _top_reverse_speed:
			# only add as much reverse accel as will keep ≤ cap
			var headroom = _top_reverse_speed - rev_spd
			var add = min(_deceleration_rate  * delta, headroom)
			velocity += forward_direction * -add
		
func tend_speed_to_zero(delta: float) -> void:
	var forward_direction = get_forward_direction()
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z) 
	var curr_spd = horizontal_velocity.length()
	var signed_spd = horizontal_velocity.dot(forward_direction)
	
	if signed_spd > 0.0:
		var speed_frac = clamp(curr_spd / top_speed, 0.0, 1.0)
		var decel = _deceleration_rate * speed_frac * delta
		decel = min(decel, curr_spd)
		var drag_dir = -horizontal_velocity.normalized()
		velocity += drag_dir * decel
	else:
		# return towards 0 if vehicle is reversing below 0 and no input
		var speed_frac = clamp(abs(signed_spd)/ _top_reverse_speed, 0.0, 1.0)
		var decel = _deceleration_rate  * speed_frac * delta
		decel = min(decel, abs(signed_spd))
		var drag_dir = -horizontal_velocity.normalized()
		velocity += drag_dir * decel
		
# turn settings
var _max_turn_rate := 1.2
var _turn_acceleration := 20.0
var _turn_curve_exponent := 2.0
var _turn_damping := 10.0
var _turn_velocity := 0.0
		
func steering(delta: float, input_turn: float) -> void:
	# base fractions
	var hspeed    = Vector3(velocity.x,0,velocity.z).length()
	var speed_frac= clamp(hspeed / top_speed, 0.0, 1.0)

	# min‐floor + sqrt ramp over first 40%
	var raw       = clamp(speed_frac / 0.5, 0.0, 1.0)
	var min_carve = 0.2
	var turn_scale= lerp(min_carve, 1.0, sqrt(raw))

	# carve‐acceleration logic 
	var target_rate = input_turn * _max_turn_rate

	var turn_frac = abs(_turn_velocity) / _max_turn_rate
	turn_frac = clamp(turn_frac, 0.0, 1.0)
	var turn_accel_scale = 1.0 - pow(turn_frac, _turn_curve_exponent)

	if input_turn == 0.0:
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
	rotate_y(actual_turn)
	velocity = velocity.rotated(Vector3.UP, actual_turn)


# gravity
func apply_character_gravity(delta: float) -> void:
	if not is_grounded():
		velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

# hover set to same height as raycast length
var _hover_height := 0.25
var _deadzone := 0.05
var _spring_k := 50
var _damping := 2 * sqrt(_spring_k)

# "pushes" board up when ray casts collide inside obejct
func apply_hover(delta: float):
	var gaps = get_corner_gaps()
	if gaps.is_empty(): return
	var avg_gap = average_gaps(gaps)
	var error = avg_gap - _hover_height
	if abs(error) > _deadzone:
		var force = -_spring_k * error
		var damp_force = -_damping * velocity.y
		velocity.y += (force + damp_force) * delta

# not in use
var _boost_impulse := 20.0
func boost():
	var forward = get_forward_direction()
	velocity += forward * _boost_impulse
	horizontal_clamp()

# UTILS

func horizontal_clamp():
	var hvel = Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > top_speed:
		hvel = hvel.normalized() * top_speed
		velocity.x = hvel.x
		velocity.z = hvel.z

# raycasts
@onready var fl = $RayCastFL
@onready var fr = $RayCastFR
@onready var bl = $RayCastBL
@onready var br = $RayCastBR

func get_corner_gaps() -> Array:
	var gaps = []
	for r in [fl, fr, bl, br]:
		if r.is_colliding():
			gaps.append(r.global_transform.origin.y - r.get_collision_point().y)
	return gaps

func average_gaps(gaps: Array) -> float:
	var total = 0.0
	for g in gaps:
		total += g
	return total / gaps.size()

func is_grounded() -> bool:
	var gaps = get_corner_gaps()
	# if no ray is hitting, we’re clearly airborne
	if gaps.is_empty():
		return false

	# if any corner is within hover_height + deadzone, we consider ourselves grounded
	var threshold = _hover_height + _deadzone
	for gap in gaps:
		if gap <= threshold:
			return true
	return false

# airtime tracking
var _in_air := false
var current_air_time := 0.0
var last_air_time := 0.0

func _update_air_time(delta):
	var grounded = is_grounded()
	if not grounded:
		# we’re airborne: accumulate
		current_air_time += delta
		_in_air = true
	elif _in_air:
		# we just landed: record and reset
		last_air_time = current_air_time
		current_air_time = 0.0
		_in_air = false

# helper function for rotating to bank
func step_angle(current: float, target: float, max_step: float) -> float:
	# signed difference wrapped into (–π … +π]
	var diff = wrapf(target - current, -PI, PI)
	# clamp that diff to our max_step
	var step = clamp(diff, -max_step, max_step)
	return current + step

func get_forward_direction() -> Vector3:
	# the board’s “nose” is –Z in its local basis
	return -global_transform.basis.z.normalized()
	
func get_horizontal_speed() -> float:
	var hvel := Vector3(velocity.x, 0, velocity.z)
	return hvel.length()

func get_side_axis() -> Vector3:
	# basis.x is the local +X axis in world coords
	return global_transform.basis.x.normalized()

func clear_lateral_velocity():
	var side = get_side_axis()
	var lat = velocity.dot(side)
	velocity -= side * lat
