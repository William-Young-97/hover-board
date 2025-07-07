extends CharacterBody3D
# hover set to same hieght as raycast length
var hover_height := 0.25
var deadzone := 0.05
var spring_k := 50
var damping := 2 * sqrt(spring_k)

# airtime tracking
var _in_air := false
var current_air_time := 0.0
var last_air_time := 0.0

# turn settings
var max_turn_rate := 1.5
var turn_acceleration := 8.0
var turn_curve_exponent := 2.0
var turn_damping := 10.0
var _turn_velocity := 0.0

# forward acceleration
var max_acceleration := 8.0
var top_speed := 50.0

# backward acceleration
var deceleration_rate := 10.0
var top_reverse_speed := 7.5

# jump settings
var jump_strength := 2.45 
var _jump_active := false

# jump banking
var jump_bank_angle := deg_to_rad(20)  # how much to bank
var bank_speed := 5.0         # radians/sec
var _base_jump_yaw := 0.0 # set at jump initiation 
var _bank_active := false # set when a direction is picked with jump
var _bank_target_yaw := Vector3.ZERO # set when bank active

# boost
var boost_duration := 1.0
var boost_multiplier := 1.0
var boost_impulse := 20.0

# gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# raycasts
@onready var fl = $RayCastFL
@onready var fr = $RayCastFR
@onready var bl = $RayCastBL
@onready var br = $RayCastBR

func _physics_process(delta: float) -> void:
	# uncomment to see how long we are airbourne
	#_update_air_time(delta)
	#if not is_grounded():
		#print(current_air_time)
	
	# apply_hover resets us to the max ray cast distance "pushes up"
	if not _jump_active and is_grounded():
		apply_hover(delta)
	
	# responses to input executed in here
	_handle_input(delta)
	
	# when grounded kill y velocity
	horizontal_clamp()
	# apply gravity to y velocity when airbourne 
	apply_character_gravity(delta)
	# default mechanic for moving character controller
	move_and_slide()


func _handle_input(delta: float) -> void:
	var _forward := Input.is_action_pressed("forward")
	var _backward := Input.is_action_pressed("back")
	var _left := Input.is_action_pressed("left")
	var _right := Input.is_action_pressed("right")
	var _boost := Input.is_action_just_pressed("boost")
	var _jump := Input.is_action_just_pressed("jump_drift")
	var _drift_held := Input.is_action_pressed("jump_drift")
	
	if _forward:
		accelerate(delta)
	
	if _backward:
		decelerate(delta)
	if not _forward and not _backward:
		tend_speed_to_zero(delta)
	
	
	# define left or right outside steering
	var _turn_input := 0.0
	if _left:
		_turn_input += 1.0
	if _right:
		_turn_input -= 1.0
	
	# Cant steer in jump
	if not _jump_active:
		steering(delta, _turn_input)

	if _boost:
		boost()
	
	var grounded := is_grounded()
	
	if _jump and grounded and not _jump_active:
		_jump_active = true
		jump(delta)
	
	if _jump_active and not grounded and _drift_held:
		# lock bank direction
		if not _bank_active:
		# calculate relative target to move too
			if _left:
				_bank_target_yaw.y = _base_jump_yaw + jump_bank_angle
				_bank_active = true
			if _right:
				_bank_target_yaw.y = _base_jump_yaw - jump_bank_angle
				_bank_active = true
				
	if _bank_active:
		rotate_to_drift_start_pos(delta) 
	
	if _jump_active and not grounded and velocity.y <= 0.0:
		var fall_multiplier := 4.0
		# speed up falling but not rising
		self.velocity.y -= gravity * fall_multiplier * delta
		
	if _jump_active and grounded and velocity.y <= 0.0:
		_jump_active = false
		
		
func accelerate(delta: float) -> void:
	var zero_y := 0
	# Keeping hvel so we can seperate air velocity from ground velocity for now
	# Gives more seperation for grounded and airbourne states
	var horizontal_velocity := Vector3(velocity.x, zero_y, velocity.z)
	var forward_direction = -global_transform.basis.z.normalized()
	forward_direction.y = zero_y 
	forward_direction = forward_direction.normalized() 
	var curr_spd := horizontal_velocity.length()
	var speed_frac = clamp(curr_spd / top_speed, 0.0, 1.0)
	var accel_strength = max_acceleration * (1.0 - speed_frac * speed_frac)
	
	self.velocity += forward_direction  * accel_strength * delta

		
func decelerate(delta: float) -> void:
	var forward_direction = -global_transform.basis.z.normalized()
	forward_direction.y = 0
	forward_direction = forward_direction.normalized() 
	var hvel    = Vector3(velocity.x, 0, velocity.z)
	var curr_spd = hvel.length()
	var signed_spd = hvel.dot(forward_direction)  # +ve → forward, -ve → backward

	if signed_spd > 0.0:
		# brake toward zero
		var decel = min(deceleration_rate * delta, signed_spd)
		velocity += -forward_direction * decel
	else:
		# creeping backward, but clamp to top_reverse_speed
		var rev_spd = abs(signed_spd)
		if rev_spd < top_reverse_speed:
			# only add as much reverse accel as will keep you ≤ cap
			var headroom = top_reverse_speed - rev_spd
			var add = min(deceleration_rate  * delta, headroom)
			velocity += forward_direction * -add
		
func tend_speed_to_zero(delta: float) -> void:
	var forward_direction = -global_transform.basis.z.normalized()
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z) 
	var curr_spd = horizontal_velocity.length()
	var signed_spd = horizontal_velocity.dot(forward_direction)
	
	if signed_spd > 0.0:
		var speed_frac = clamp(curr_spd / top_speed, 0.0, 1.0)
		var decel = deceleration_rate * speed_frac * delta
		decel = min(decel, curr_spd)
		var drag_dir = -horizontal_velocity.normalized()
		velocity += drag_dir * decel
	else:
		# return towards 0 if vehicle is reversing below 0 and no input
		var speed_frac = clamp(abs(signed_spd)/ top_reverse_speed, 0.0, 1.0)
		var decel = deceleration_rate  * speed_frac * delta
		decel = min(decel, abs(signed_spd))
		var drag_dir = -horizontal_velocity.normalized()
		velocity += drag_dir * decel
		
func steering(delta: float, turn_input: float) -> void:
	# base fractions
	var hspeed    = Vector3(velocity.x,0,velocity.z).length()
	var speed_frac= clamp(hspeed / top_speed, 0.0, 1.0)

	# min‐floor + sqrt ramp over first 40%
	var raw       = clamp(speed_frac / 0.4, 0.0, 1.0)
	var min_carve = 0.2
	var turn_scale= lerp(min_carve, 1.0, sqrt(raw))

	# carve‐acceleration logic 
	var target_rate = turn_input * max_turn_rate

	var turn_frac = abs(_turn_velocity) / max_turn_rate
	turn_frac = clamp(turn_frac, 0.0, 1.0)
	var turn_accel_scale = 1.0 - pow(turn_frac, turn_curve_exponent)

	if turn_input == 0.0:
		# bleed‐off
		_turn_velocity = lerp(_turn_velocity, 0.0, turn_damping * delta)
	else:
		var rate_diff = target_rate - _turn_velocity
		var effective_scale = 1.0 if rate_diff * _turn_velocity < 0.0 else turn_accel_scale

		# angular accel scaled by speed
		var applied_accel = sign(rate_diff) \
			* turn_acceleration \
			* effective_scale \
			* turn_scale
		_turn_velocity += applied_accel * delta

	_turn_velocity = clamp(_turn_velocity, -max_turn_rate, max_turn_rate)

	# carve body by a scaled amount
	var actual_turn = _turn_velocity * turn_scale * delta
	rotate_y(actual_turn)
	velocity = velocity.rotated(Vector3.UP, actual_turn)

# how is this going to interact with our gravity and airbourne function
# Want half a second of airtime
func jump(delta: float) -> void:
	velocity += Vector3(0, jump_strength ,0)
	# take this so we can update relative banking
	_base_jump_yaw = rotation.y
	
func rotate_to_drift_start_pos(delta):
	var current_yaw := rotation.y
	# max radians we’re allowed to turn this frame
	var max_step = bank_speed * delta
	# step along the shortest arc toward one‐time target
	var new_yaw = step_angle(current_yaw, _bank_target_yaw.y, max_step)
	var delta_y = new_yaw - current_yaw

	rotation.y = new_yaw
	# carry momentum (make this a seperate function)
	# velocity = velocity.rotated(Vector3.UP, delta_y)
	
	# once we’re close enough, stop
	if abs(wrapf(_bank_target_yaw.y - new_yaw, -PI, PI)) < 0.001:
		_bank_active = false


func apply_drift(delta: float) -> void:
	pass
		
#func apply_drift(delta):
	#if _drift_pressed and not drift_active:
		#var hvel = Vector3(velocity.x, 0, velocity.z)
		#if Input.is_action_pressed("left"):
			#drift_dir = +1
		#elif Input.is_action_pressed("right"):
			#drift_dir = -1
		#else:
			#return
		#drift_entry_speed = hvel.length()
		#drift_active = true
		#drift_target_yaw = rotation.y + default_drift_angle * drift_dir
#
	#if drift_active and _drift_held:
		#var new_yaw = lerp_angle(rotation.y, drift_target_yaw, drift_smooth_speed * delta)
		#var angle_delta = new_yaw - rotation.y
		#rotation.y = new_yaw
#
		#velocity = velocity.rotated(Vector3.UP, angle_delta)
		#var fwd = -global_transform.basis.z.normalized()
		#var side = velocity - fwd * velocity.dot(fwd)
		#velocity.x = fwd.x * drift_entry_speed + side.x
		#velocity.z = fwd.z * drift_entry_speed + side.z
#
	#
		#var lateral_acc = drift_entry_speed * drift_velocity_ratio
		#velocity += global_transform.basis.x * drift_dir * lateral_acc * delta
		#return
#
#
	#if _drift_released:
		#var lateral_dir = global_transform.basis.x.normalized()
		#var lat_spd = velocity.dot(lateral_dir)
		#velocity -= lateral_dir * lat_spd
#
		#drift_active = false
		#drift_entry_speed = 0.0

# gravity
func apply_character_gravity(delta: float) -> void:
	if not is_grounded():
		velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

# "pushes" board up when ray casts collide inside obejct
func apply_hover(delta: float):

	var gaps = get_corner_gaps()
	if gaps.is_empty(): return
	var avg_gap = average_gaps(gaps)
	var error = avg_gap - hover_height
	if abs(error) > deadzone:
		var force = -spring_k * error
		var damp_force = -damping * velocity.y
		velocity.y += (force + damp_force) * delta

func boost():
	var forward = -global_transform.basis.z.normalized()
	velocity += forward * boost_impulse
	horizontal_clamp()

# UTILS

func horizontal_clamp():
	var hvel = Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > top_speed:
		hvel = hvel.normalized() * top_speed
		velocity.x = hvel.x
		velocity.z = hvel.z

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
	var threshold = hover_height + deadzone
	for gap in gaps:
		if gap <= threshold:
			return true
	return false

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
