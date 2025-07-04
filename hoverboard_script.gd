extends CharacterBody3D
# hover
@export var hover_height := 0.2
@export var deadzone := 0.1
@export var spring_k := 10.0
@export var damping := 15.0

# turning
@export var max_turn_rate := 1.5
@export var turn_acceleration := 8.0
@export var turn_curve_exponent := 2.0
@export var turn_damping := 10.0

# forward acceleration
@export var max_acceleration := 8.0
@export var top_speed := 50.0

@export var deceleration_rate := 10.0
@export var top_reverse_speed := 7.5

# drift
#@export var drift_speed_threshold_mph := 20.0
#@export var default_drift_angle := 2.0
#@export var drift_smooth_speed := 1.0
#@export var drift_velocity_ratio := 0.8

# boost
@export var boost_duration := 1.0
@export var boost_multiplier := 1.0
@export var boost_impulse := 20.0

# gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# raycasts
@onready var fl = $RayCastFL
@onready var fr = $RayCastFR
@onready var bl = $RayCastBL
@onready var br = $RayCastBR

# ——————————————————————————————————————————————————
# STATE
# ——————————————————————————————————————————————————
# steering
var _turn_velocity := 0.0

# drift
var drift_active := false
var drift_dir := 0
var drift_target_yaw := 0.0
var drift_entry_speed := 0.0

# transient input fields
var _input_dir := Vector3.ZERO
var _turn_input := 0.0

#var _drift_pressed := false
#var _drift_held := false
#var _drift_released := false


func _physics_process(delta):
	_handle_input(delta)
	apply_character_gravity(delta)
	apply_hover(delta)
	horizontal_clamp()
	move_and_slide()


func _handle_input(delta):
	var _forward := Input.is_action_pressed("forward")
	var _backward := Input.is_action_pressed("back")
	var _left := Input.is_action_pressed("left")
	var _right := Input.is_action_pressed("right")
	var _boost := Input.is_action_just_pressed("boost")
	#var _drift_pressed := Input.is_action_pressed("drift")
	#var _drift_held := Input.is_action_pressed("drift")
	
	if _forward:
		accelerate(delta)
	
	if _backward:
		decelerate(delta)
	if not _forward and not _backward:
		tend_speed_to_zero(delta)
	
	
	# turn
	_turn_input = 0.0
	if _left:
		_turn_input += 1.0
	if _right:
		_turn_input -= 1.0

	steering(delta, _turn_input)

	if _boost:
		boost()
	
	#if _drift_pressed:
		#apply_drift(delta)


func accelerate(delta):
	# Keeping hvel so we can seperate air velocity from ground velocity for now
	# Gives more seperation for grounded and airbourne states
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
	var forward_direction = -global_transform.basis.z.normalized() 
	var curr_spd := horizontal_velocity.length()
	var speed_frac = clamp(curr_spd / top_speed, 0.0, 1.0)
	var accel_strength = max_acceleration * (1.0 - speed_frac * speed_frac)
	
	self.velocity += forward_direction  * accel_strength * delta

		
func decelerate(delta):
	var forward_direction = -global_transform.basis.z.normalized()
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
		
func tend_speed_to_zero(delta):
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
		
func steering(delta, turn_input: float):
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

	# carve your body by a scaled amount
	var actual_turn = _turn_velocity * turn_scale * delta
	rotate_y(actual_turn)
	velocity = velocity.rotated(Vector3.UP, actual_turn)


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

# Gravity

func apply_character_gravity(delta):
	if is_airborne():
		velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

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

func apply_hover(delta):
	var gaps = get_corner_gaps()
	if gaps.is_empty(): return
	var avg_gap = average_gaps(gaps)
	var error = avg_gap - hover_height
	if abs(error) > deadzone:
		var force = -spring_k * error
		var damp_force = -damping * velocity.y
		velocity.y += (force + damp_force) * delta


# Utils
func horizontal_clamp():
	var hvel = Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > top_speed:
		hvel = hvel.normalized() * top_speed
		velocity.x = hvel.x
		velocity.z = hvel.z

func boost():
	var forward = -global_transform.basis.z.normalized()
	velocity += forward * boost_impulse
	horizontal_clamp()

func is_airborne() -> bool:
	var gaps = get_corner_gaps()
	if gaps.is_empty():
		return true
	return average_gaps(gaps) > (hover_height + deadzone)
