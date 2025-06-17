extends CharacterBody3D

# To do
# Have board correctly change orientation when navigating a slope
# Ensure that gravity works to pull the board down into position? (how will this
# work with oreinting the slope?)
# Ensure that velocity is carried into jumps (rigidbody3d attached to CB3D?)
 
@export var hover_height := 0.2
var deadzone  = 0.1
var spring_k  = 10.0   # tweak for stiffness
var damping   = 8.0    # tweak for bounce damping

# this acts moe like the cap for my top speed
@export var speed := 10.0 
@export var turn_speed := 5.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var fl = $RayCastFL
@onready var fr = $RayCastFR
@onready var bl = $RayCastBL
@onready var br = $RayCastBR

func _physics_process(delta):
		
	get_input(delta)
	apply_character_gravity(delta)
	apply_hover(delta)
	# without locking y to 0 then by default moving forward increases y velocity
	# velocity.y = 0
	print(velocity.y)
	move_and_slide()

func get_input(delta):
	var accel_dir := Vector3.ZERO

	if Input.is_action_pressed("forward"):
		accel_dir -= global_transform.basis.z
		print(global_transform.basis)
	if Input.is_action_pressed("back"):
		accel_dir += global_transform.basis.z

	if accel_dir != Vector3.ZERO:
		accel_dir = accel_dir.normalized() * speed

	# integrate velocity into direction
	velocity.x = velocity.x + accel_dir.x * delta
	velocity.z = velocity.z + accel_dir.z * delta

	# turn the board AND rotate velocity vector
	var turn_amount := 0.0
	if Input.is_action_pressed("left"):
		turn_amount += turn_speed * delta
	if Input.is_action_pressed("right"):
		turn_amount -= turn_speed * delta

	# try to "keep" some previous velocity
	if turn_amount != 0.0:
		rotate_y(turn_amount)
		velocity = velocity.rotated(Vector3.UP, turn_amount)

	# clamp horizontal speed so it doesn't go to infinite
	# cancel out hortizontal magnitude if it is higher than forward and reassign to forward magnitude
	var hvel := Vector3(velocity.x, 0, velocity.z)
	var hspeed := hvel.length()
	if hspeed > speed:
		hvel = hvel.normalized() * speed
		velocity.x = hvel.x
		velocity.z = hvel.z
		#
	#print("Speed (3D): ", velocity.length())

func is_airborne() -> bool:
	var gaps := []
	# Collect the world-space “gap” from each corner to the surface.
	for r in [fl, fr, bl, br]:
		if r.is_colliding():
			# distance = origin_y - hit_y
			var gap = r.global_transform.origin.y - r.get_collision_point().y
			gaps.append(gap)

	# No rays hit within 0.2m → you’re clearly airborne
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
	
