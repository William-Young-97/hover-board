extends CharacterBody3D

# To do
# Implement drift
# Have board correctly change orientation when navigating a slope
# Board gains speed when accelerating into objects
# Improve airbourne physics
 
# hover variables
var hover_height := 0.2
var deadzone  = 0.1
var spring_k  = 10.0  
var damping   = 15.0    

# turning variables
var max_turn_rate := 1.5 # (radians/sec)
# how quickly you accelerate your turning (radians/sec²) when starting a carve
var turn_acceleration := 10
# curve exponent: 1 = linear fall-off, 2 = quadratic, 3 = cubic…
var turn_curve_exponent := 2
# how quickly turn velocity bleeds to zero
var turn_damping          := 10.0   
# internal angular velocity state
var _turn_velocity := 0.0

var max_acceleration := 8.0    # units/sec² when standing still
var top_speed        := 50.0 

var deceleration_rate := 10.0

var drift_active := false
var drift_dir    := 0
var drift_target_yaw := 0.0
var drift_smooth_speed := 1
var drift_speed_threshold_mph := 20.0   # min speed to allow drift
var default_drift_angle := 2          # radians to yaw when drift starts
var drift_velocity_ratio := 0.8  
var drift_entry_speed := 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Boost parametersw
@export var boost_duration := 1.0       # seconds of boost
@export var boost_multiplier := 1.0     # multiplies accel during boost
@export var boost_impulse := 20.0   # units of instantaneous speed added



@onready var fl = $RayCastFL
@onready var fr = $RayCastFR
@onready var bl = $RayCastBL
@onready var br = $RayCastBR



func _physics_process(delta):
	get_input(delta)
	apply_character_gravity(delta)
	apply_hover(delta)
	apply_drift(delta)
	horizontal_clamp()
	move_and_slide()
	

func get_input(delta):

	# 1) Directional input vector
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("forward"):
		input_dir -= global_transform.basis.z
	if Input.is_action_pressed("back"):
		input_dir += global_transform.basis.z
	if not drift_active:
		accelerate(delta)

	# Turn input
	var turn_input := 0.0
	if Input.is_action_pressed("left"):
		turn_input += 1.0
	if Input.is_action_pressed("right"):
		turn_input -= 1.0
	
	steering(delta, turn_input)
	
	if Input.is_action_just_pressed("boost"):
		self.boost()
	
	if Input.is_action_just_pressed("drift"):
		pass
		
func accelerate(delta):
	# determine input state
	var forward_input = Input.is_action_pressed("forward")
	var back_input = Input.is_action_pressed("back")
	
	# current horizontal velocity and speed
	var hvel = Vector3(velocity.x, 0, velocity.z)
	var curr_spd = hvel.length()
	var speed_frac = clamp(curr_spd / top_speed, 0.0, 1.0)
	
	if forward_input:
		# forward acceleration with tapered curve
		var accel_strength = max_acceleration * (1.0 - speed_frac * speed_frac)
		var dir = -global_transform.basis.z.normalized()
		velocity += dir * accel_strength * delta
	elif back_input:
		# braking: stronger deceleration at higher speeds
		if curr_spd > 0.0:
			var decel = deceleration_rate   * delta
			decel = min(decel, curr_spd)
			var drag_dir = -hvel.normalized()
			velocity += drag_dir * decel
	else:
		# coasting drag: gradient decel (more at high speed)
		if curr_spd > 0.0:
			var decel = deceleration_rate * speed_frac * delta
			decel = min(decel, curr_spd)
			var drag_dir = -hvel.normalized()
			velocity += drag_dir * decel
		


func steering(delta, turn_input):
	var target_rate = turn_input * max_turn_rate

	# Compute how “full” our current carve is
	var turn_frac = abs(_turn_velocity) / max_turn_rate
	turn_frac = clamp(turn_frac, 0.0, 1.0)
	var turn_accel_scale = 1.0 - pow(turn_frac, turn_curve_exponent)

	if turn_input == 0.0:
		# bleed off when you let go
		_turn_velocity = lerp(_turn_velocity, 0.0, turn_damping * delta)
	else:
		var rate_diff = target_rate - _turn_velocity

		# If reversing direction, slam on full carve authority
		var effective_scale = turn_accel_scale
		if rate_diff * _turn_velocity < 0:
			effective_scale = 1.0

		var applied_accel = sign(rate_diff) * turn_acceleration * effective_scale
		_turn_velocity += applied_accel * delta
	_turn_velocity = clamp(_turn_velocity, -max_turn_rate, max_turn_rate)

	var actual_turn = _turn_velocity * delta
	rotate_y(actual_turn)
	velocity = velocity.rotated(Vector3.UP, actual_turn)


func horizontal_clamp():
	var hvel = Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > top_speed:
		hvel = hvel.normalized() * top_speed
		velocity.x = hvel.x
		velocity.z = hvel.z

func boost():

	# 1) get the normalized forward vector
	var forward = -global_transform.basis.z.normalized()
	# 2) apply an instantaneous velocity impulse
	velocity += forward * boost_impulse
	# 3) optional: cap at top speed so you don't overshoot too far
	var hvel = Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > top_speed:
		hvel = hvel.normalized() * top_speed
		velocity.x = hvel.x
		velocity.z = hvel.z

# refactor into signal pattern
func apply_drift(delta):
	# 1) Arm the drift on press
	if Input.is_action_just_pressed("drift") and not drift_active:
		var hvel = Vector3(velocity.x, 0, velocity.z)
		var speed_mph = hvel.length() * 2.23694
		if speed_mph < drift_speed_threshold_mph:
			return
		if Input.is_action_pressed("left"):
			drift_dir = +1
		elif Input.is_action_pressed("right"):
			drift_dir = -1
		else:
			return

		# **capture your entry speed (world units/sec)**
		drift_entry_speed = hvel.length()
		drift_active = true
		drift_target_yaw = rotation.y + default_drift_angle * drift_dir

	# 2) While held, carve and push sideways
	if drift_active and Input.is_action_pressed("drift"):
		# — smooth yaw carve —
		var new_yaw = lerp_angle(rotation.y, drift_target_yaw, drift_smooth_speed * delta)
		var angle_delta = new_yaw - rotation.y
		rotation.y = new_yaw

		# — re‐orient and LOCK your forward speed —
		# rotate the direction of your velocity without changing entry speed
		var forward_dir = -global_transform.basis.z.normalized()
		# carve your velocity direction
		velocity = velocity.rotated(Vector3.UP, angle_delta)
		# now override the forward component to exactly the drift_entry_speed
		var side_vel = Vector3(velocity.x, 0, velocity.z) - forward_dir * forward_dir.dot(Vector3(velocity.x,0,velocity.z))
		velocity.x = forward_dir.x * drift_entry_speed + side_vel.x
		velocity.z = forward_dir.z * drift_entry_speed + side_vel.z

		# — lateral slide on top —
		var lateral_acc = drift_entry_speed * drift_velocity_ratio
		var side_dir = global_transform.basis.x * drift_dir
		velocity += side_dir * (lateral_acc * delta)

		return

	# 3) End on release: remove any sideways and unlock
	if drift_active and Input.is_action_just_released("drift"):
		var lateral_dir = global_transform.basis.x.normalized()
		var lat_spd = velocity.dot(lateral_dir)
		velocity -= lateral_dir * lat_spd

		drift_active = false
		drift_entry_speed = 0.0
		
func is_airborne() -> bool:
	var gaps := []
	# Collect the world-space “gap” from each corner to the surface.
	for r in [fl, fr, bl, br]:
		if r.is_colliding():
			# distance = origin_y - hit_y
			var gap = r.global_transform.origin.y - r.get_collision_point().y
			gaps.append(gap)

	# No rays hit within 0.2m clearly airborne
	if gaps.is_empty():
		return true

	# Compute the average gap
	var avg_gap := 0.0
	for g in gaps:
		avg_gap += g
	avg_gap /= gaps.size()

	# If you’re above your hover band, you’re airborne
	return avg_gap > (hover_height + deadzone)
	
func apply_character_gravity(delta):
	# 1) Detect “airborne” state:
	#    You're airborne if your average hover-ray distance is significantly
	#    above hover_height + dead_zone (or no rays colliding).
	var airborne = is_airborne()

	# 2) If airborne, accelerate downward:
	if airborne:
		velocity.y -= gravity * delta
	else:
		# zero‐out any tiny downward velocity
		velocity.y = max(velocity.y, 0)

func get_corner_gaps() -> Array:
	var gaps: Array = []
	for ray in [fl, fr, bl, br]:
		if ray.is_colliding():
			# world-space origin of the ray
			var origin_y = ray.global_transform.origin.y
			# point on the surface
			var hit_y    = ray.get_collision_point().y
			# gap between board corner and ground
			gaps.append(origin_y - hit_y)
	return gaps

func average_gaps(gaps):
	var total := 0.0
	for gap in gaps:
		total += gap
	return total / gaps.size()
		
func apply_hover(delta):
	# 1) Gather the corner gaps (origin.y - hit.y)
	var gaps = get_corner_gaps()
	var avg_gap = average_gaps(gaps)
	var error = avg_gap - hover_height
	
	# 3) If outside deadzone, apply a spring‐damper force
	if abs(error) > deadzone:
		# spring: F = -k * error
		var force = -spring_k * error
		# damper: F_d = -d * velocity.y
		var damp  = -damping  * velocity.y
		velocity.y += (force + damp) * delta
