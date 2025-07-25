extends Node
class_name DriftHelper

# todo: emit signal to keep drift camera locked in place for left and right drifts
# Solve the redirection of out velocity to the inward nuetral position

var ti: TerrainInteractions
var vrc: VisualRollController
var outward_carve = false
var inward_carve = false

func _init(_terrain_interactions: TerrainInteractions, _visual_roll_controller: VisualRollController) -> void:
	ti = _terrain_interactions
	vrc = _visual_roll_controller

var _inward_drift_timer = 0
var hf = HelperFunctions.new()

func enter(character: Character, delta) -> void:
	vrc .board_roll_amount = 0.8

# this method will switch to handle left vs right drift
func _apply_drift(character: Character, delta):
	# extra guard against drift not releasing
	if not character.input_jump_held:
		return GroundState
	var side = HelperFunctions.get_side_axis(character)
	
	if character.left_drift:
		if not outward_carve and not inward_carve:
			self._apply_drift_side_pull(character, -1, delta)
			
		vrc.direction += 1
		if character.input_left:
			character.drift_dir = 1	
			var max_yaw = self._scale_drift_yaw_to_speed(character, delta)
			self._scale_yaw_to_input(character, delta, max_yaw, character.drift_dir)
			self._apply_inward_drift_velocity_blend(character, delta)
			inward_carve = true
			outward_carve = false
		elif character.input_right:
			character.drift_dir = 1
			_inward_drift_timer = 0
			outward_carve = true
			inward_carve = false
			self._apply_outward_drift(character, character.drift_dir, delta)
		else:
			_inward_drift_timer = 0
			inward_carve = false
			outward_carve = false
			
	elif character.right_drift:
		if not outward_carve and not inward_carve:
			self._apply_drift_side_pull(character, 1, delta)
		vrc.direction -= 1
		if character.input_right:
			character.drift_dir = -1
			var max_yaw = self._scale_drift_yaw_to_speed(character, delta)
			self._scale_yaw_to_input(character, delta, max_yaw, character.drift_dir)
			self._apply_inward_drift_velocity_blend(character, delta)
			inward_carve = true
			outward_carve = false
		elif character.input_left:
			character.drift_dir = -1
			_inward_drift_timer = 0
			self._apply_outward_drift(character, character.drift_dir, delta)
			outward_carve = true
			inward_carve = false
		else:
			_inward_drift_timer = 0
			inward_carve = false
			outward_carve = false
			
func _apply_drift_side_pull(character: Character, drift_dir: int, delta: float) -> void:
	var pull_and_yaw := 0.5
	# 1) slope normal
	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n

	# 2) planar basis axes
	var raw_fwd = -character.global_transform.basis.z.normalized()
	var forward_on_plane = (raw_fwd - n * raw_fwd.dot(n)).normalized()
	var side_on_plane    = n.cross(forward_on_plane).normalized()

	# 3) decompose velocity
	var old_v       = character.velocity
	var normal_spd  = old_v.dot(n)
	var planar_v    = old_v - n * normal_spd
	var planar_spd  = planar_v.length()
	if planar_spd < 0.001:
		return  # nothing to pull

	# 4) find inward‑side unit axis
	#    drift_dir = +1 for left‑drift, -1 for right‑drift,
	#    side_on_plane points “outside” if we keep the reference convention,
	#    so invert it to get the *inside* direction:
	var inward_side = -drift_dir * side_on_plane

	# 5) blend current heading toward inward_side
	#    choose a small blend rate so it smoothly pulls in over time:
	var pull_strength = pull_and_yaw # tune this (0=no pull, 1=immediate lock)
	var blend = clamp(pull_strength * delta, 0.0, 1.0)

	# current planar heading:
	var planar_dir = planar_v / planar_spd
	# new heading is a lerp between where you are and the inside side:
	var new_dir = planar_dir.lerp(inward_side, blend).normalized()

	# 6) rebuild planar velocity at the same total speed
	var new_planar_v = new_dir * planar_spd

	# 7) reassemble full velocity (plane + normal)
	character.velocity = new_planar_v + n * normal_spd
	
		# 8) now align the board’s yaw to the new planar velocity
	#    a) get the same planar forward axis
	raw_fwd = -character.global_transform.basis.z.normalized()
	forward_on_plane = (raw_fwd - n * raw_fwd.dot(n)).normalized()

	#    b) compute the signed angle between it and new_dir
	var dot = clamp(forward_on_plane.dot(new_dir), -1.0, 1.0)
	var angle = acos(dot)
	#    c) determine sign via cross·normal
	var sign = 0
	if forward_on_plane.cross(new_dir).dot(n) < 0 :
		sign = 1
	else:
		sign = -1

	#    d) step just partway each frame for smoothness
	var yaw_speed = pull_and_yaw # radians/sec max turn rate
	var step = min(angle, yaw_speed * delta)

	#    e) apply the rotation around the slope normal
	character.rotate_object_local(n, step * sign)
	
func _apply_outward_drift(character: Character, drift_dir: int, delta: float) -> void:
	# 1) get the up‐vector of the slope
	var n = ti.get_ground_normal(ti.grays)
	# ensure it points up
	if n.dot(Vector3.UP) < 0: n = -n

	# 2) build your planar axes:
	#    forward_on_plane: board nose projected onto plane
	var raw_forward = -character.global_transform.basis.z.normalized()
	var forward_on_plane = (raw_forward - n * raw_forward.dot(n)).normalized()
	#    side_on_plane: perpendicular in that plane
	var side_on_plane = n.cross(forward_on_plane).normalized()

	# 3) decompose your *current* velocity into planar and normal parts
	var old_v     = character.velocity
	var vertical_spd = old_v.dot(n)
	var planar_v  = old_v - n * vertical_spd

	# 4) split planar into forward & side scalars
	var fwd_spd = forward_on_plane.dot(planar_v)
	var lat_spd = side_on_plane.dot(planar_v)

	# 5) compute shift
	var shift_rate = 0.5
	var shift      = min(fwd_spd, fwd_spd * shift_rate * delta)
	var outward_dir = -drift_dir
	# 6) reassign
	fwd_spd -= shift
	lat_spd += outward_dir * shift

	# 7) rebuild planar velocity
	var new_planar_v = forward_on_plane * fwd_spd + side_on_plane * lat_spd
	# 8) stitch back vertical
	character.velocity = new_planar_v + n * vertical_spd

# drifting becomes more effective at higher speeds
func _scale_drift_yaw_to_speed(character: Character, delta) -> float:
	var starting_yaw_rate := 1.0 
	var max_yaw_rate      := 1.9 
	var min_carve_frac    := 0.2 
	var hvel = ti.get_hvel_relative_to_surface(character, ti.grays)
	# kind of doubling up the above func but trying to ensure speed_frac
	# only works with "forward" velocity
	var n = ti.get_ground_normal(ti.grays)
	var raw_fwd           = -character.global_transform.basis.z.normalized()
	var forward_on_plane = (raw_fwd - n * raw_fwd.dot(n)).normalized()
	var fwd_spd          = forward_on_plane.dot(hvel)  # how much of your planar motion is actually forward

	var speed_frac       = clamp(fwd_spd / character.top_speed, 0.0, 1.0)
	var carve_scale = lerp(min_carve_frac, 1.0, sqrt(speed_frac))
	var out_yaw_rate = lerp(starting_yaw_rate, max_yaw_rate, carve_scale)
	
	return out_yaw_rate
	
# build yaw based on time input held
func _scale_yaw_to_input(character: Character, delta, max_yaw,  drift_dir):
	var max_hold_time = 0.5
	var starting_yaw_rate := 1.3
	var inward_held := false
	
	if  drift_dir == 1:
		inward_held = character.input_left
	elif  drift_dir == -1:
		inward_held = character.input_right

	if inward_held:
		_inward_drift_timer = min(_inward_drift_timer + delta, max_hold_time)
	else:
		_inward_drift_timer = 0
	
	var t = _inward_drift_timer / max_hold_time # 0→1 over that second
	var applied_yaw = lerp(starting_yaw_rate, max_yaw, t)
	
	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n
	
	var angle = drift_dir * applied_yaw * delta
	var q = Quaternion(n, angle)
	var b = character.global_transform.basis
	character.global_transform.basis = (Basis(q) * b).orthonormalized()
	

var drift_vel_blend := 5
func _apply_inward_drift_velocity_blend(character: Character, delta: float) -> void:
	# slope normal
	var n = ti.get_ground_normal( ti.arays)

	# old full velocity and its normal component
	var old_v    = character.velocity
	var norm_spd = old_v.dot(n)

	# planar velocity (true “on‑surface” velocity)
	var hvel = old_v.slide(n)
	var speed = hvel.length()
	if speed < 0.01:
		return

	# where board is pointing along the slope
	var nose = -character.global_transform.basis.z
	var nose_plane = (nose - n * nose.dot(n)).normalized()

	# blend current hvel‑dir toward nose_plane
	var blend = clamp(drift_vel_blend * delta, 0.0, 1.0)
	var new_dir = hvel.normalized().lerp(nose_plane, blend).normalized()
	
	# rebuild planar velocity
	var new_hvel = new_dir * speed

	# reassemble full 3D velocity: planar + preserved normal
	character.velocity = new_hvel + n * norm_spd


# increase the speed of whever the current velocity is agnositic to direction
func _accelerate_drift(character: Character, delta: float) -> void:
	var hvel = ti.get_hvel_relative_to_surface(character,  ti.arays)
	var speed = hvel.length()

	var delta_speed = HelperFunctions.calc_forward_accel_delta(character, speed, delta)
	
	var travel_dir = hvel / speed

	character.velocity += travel_dir * delta_speed

func _decelerate_drift(character: Character, delta: float) -> void:
	var decel_rate := 10.0

	# 1) find the slope‐up normal
	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n

	# 2) split current velocity into planar + normal parts
	var old_v       = character.velocity
	var normal_spd  = old_v.dot(n)               # keep this intact
	var planar_v    = old_v - n * normal_spd     # what we'll decelerate

	# 3) measure how fast you're moving in that planar direction
	var speed       = planar_v.length()
	if speed < 0.001:
		return  # nothing to decelerate

	# 4) compute deceleration delta
	var decel_amt   = min(decel_rate * delta, speed)

	# 5) rebuild the new planar velocity
	var dir         = planar_v.normalized()
	var new_planar  = dir * (speed - decel_amt)

	# 6) re‑assemble full 3D velocity
	character.velocity = new_planar + n * normal_spd

# probably a slightly unessecary guard given i dont bleed drift speed
# does guard for people trying to deccel tho so screw it

func _exit_at_20_mph(character: Character):
	var mph = HelperFunctions.get_mph(character)
	
	if mph <= 20:
		Input.action_release("jump_drift")
