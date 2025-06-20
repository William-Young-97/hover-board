extends CharacterBody3D

# To do
# Have board correctly change orientation when navigating a slope
# Ensure that gravity works to pull the board down into position? (how will this
# work with oreinting the slope?)
# Ensure that velocity is carried into jumps (rigidbody3d attached to CB3D?)
 
# hover variables
var hover_height := 0.2
var deadzone  = 0.1
var spring_k  = 10.0  
var damping   = 8.0    

# turning variables
var max_turn_rate : float = 1.5  # (radians/sec)
# how quickly you accelerate your turning (radians/sec²) when starting a carve
var turn_acceleration : float = 10.0
# curve exponent: 1 = linear fall-off, 2 = quadratic, 3 = cubic…
var turn_curve_exponent : float = 2.0
# how quickly turn velocity bleeds to zero
var turn_damping          := 5.0   
# internal angular velocity state

var _turn_velocity : float = 0.0

var max_acceleration := 10.0    # units/sec² when standing still
var top_speed        := 30.0 

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var fl = $RayCastFL
@onready var fr = $RayCastFR
@onready var bl = $RayCastBL
@onready var br = $RayCastBR



func _physics_process(delta):
	get_input(delta)
	apply_character_gravity(delta)
	apply_hover(delta)
	move_and_slide()

func accelerate(delta, input_dir):
	# Extract a unit vector to give direction
	# Without affecting magnitude
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

	# 2) Current horizontal speed fraction
	var hvel      = Vector3(velocity.x, 0, velocity.z)
	var curr_spd  = hvel.length()
	var speed_frac = clamp(curr_spd / top_speed, 0.0, 1.0)

	# 3) Compute tapered acceleration
	#    quadratic fall-off: full at 0, zero at 1
	
	# add a tool to convert my movement into mph
	var accel_strength = max_acceleration * (1.0 - speed_frac * speed_frac)
	print("accel_str: ", accel_strength)
	print("board_vel:", hvel.length())
	# 4) Integrate linear acceleration
	velocity.x += input_dir.x * accel_strength * delta
	velocity.z += input_dir.z * accel_strength * delta

func steering(delta, turn_input):
	# 6) Desired angular rate
	var target_rate = turn_input * max_turn_rate

	# 7) Angular speed fraction & accel scaling
	var turn_frac = abs(_turn_velocity) / max_turn_rate
	turn_frac = clamp(turn_frac, 0.0, 1.0)
	var turn_accel_scale = 1.0 - pow(turn_frac, turn_curve_exponent)

	# 8) Integrate angular acceleration or apply damping
	if turn_input == 0.0:
		# no input → bleed turn velocity back to zero
		_turn_velocity = lerp(_turn_velocity, 0.0, turn_damping * delta)
	else:
		var rate_diff = target_rate - _turn_velocity
		var applied_accel = sign(rate_diff) * turn_acceleration * turn_accel_scale
		_turn_velocity += applied_accel * delta

	# 9) Clamp turn velocity
	_turn_velocity = clamp(_turn_velocity, -max_turn_rate, max_turn_rate)

	# 10) Apply rotation & carve
	var actual_turn = _turn_velocity * delta
	rotate_y(actual_turn)
	velocity = velocity.rotated(Vector3.UP, actual_turn)

	# ——————————————————————————————
	# 11) Final speed clamp
	var hvel = Vector3(velocity.x, 0, velocity.z)
	if hvel.length() > top_speed:
		hvel = hvel.normalized() * top_speed
		velocity.x = hvel.x
		velocity.z = hvel.z

# refector longitudinal acceleration and turn acceleration into their own functions
func get_input(delta):
	# ——————————————————————————————
	# 1) Directional input vector
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("forward"):
		input_dir -= global_transform.basis.z
	if Input.is_action_pressed("back"):
		input_dir += global_transform.basis.z

	accelerate(delta, input_dir)
	# ——————————————————————————————
	# 5) Turn input
	var turn_input := 0.0
	if Input.is_action_pressed("left"):
		turn_input += 1.0
	if Input.is_action_pressed("right"):
		turn_input -= 1.0

	steering(delta, turn_input)
	


	#print("Speed (3D): ", velocity.length())

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
	
