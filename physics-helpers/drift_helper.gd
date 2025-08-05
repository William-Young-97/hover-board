extends Node
class_name DriftHelper

# todo: emit signal to keep drift camera locked in place for left and right drifts
# Solve the redirection of out velocity to the inward nuetral position

var ti: TerrainInteractions
var vrc: VisualRollController
var lm: Node3D
var rm: Node3D

var outward_carve = false
var inward_carve = false

func _init(_ti: TerrainInteractions, _vrc: VisualRollController, _lm: Node3D, _rm: Node3D) -> void:
	ti = _ti
	vrc = _vrc
	lm = _lm
	rm = _rm

var _inward_drift_timer = 0
var hf = HelperFunctions.new()

func enter(character: Character, delta) -> void:
	vrc.board_roll_amount = 0.8
	
	
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

	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n

	var raw_fwd          = -character.global_transform.basis.z.normalized()
	var forward_on_plane = (raw_fwd - n * raw_fwd.dot(n)).normalized()
	var side_on_plane    = n.cross(forward_on_plane).normalized()

	var old_v      = character.velocity
	var normal_spd = old_v.dot(n)
	var planar_v   = old_v - n * normal_spd
	var planar_spd = planar_v.length()
	if planar_spd < 0.001:
		return

	var inward_side = -drift_dir * side_on_plane

	var blend = clamp(pull_and_yaw * delta, 0.0, 1.0)
	var planar_dir = planar_v / planar_spd
	var new_dir    = planar_dir.lerp(inward_side, blend).normalized()

	var new_planar_v = new_dir * planar_spd
	character.velocity = new_planar_v + n * normal_spd

	var cosθ = clamp(planar_dir.dot(new_dir), -1.0, 1.0)
	var sinθ = n.dot(planar_dir.cross(new_dir))
	var delta_angle = atan2(sinθ, cosθ)

	var q = Quaternion(n, delta_angle)
	var b = character.global_transform.basis
	character.global_transform.basis = (Basis(q) * b)

func _apply_outward_drift(character: Character, drift_dir: int, delta: float) -> void:
	var pull_and_yaw := 0.05

	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n

	var raw_fwd          = -character.global_transform.basis.z.normalized()
	var forward_on_plane = (raw_fwd - n * raw_fwd.dot(n)).normalized()
	var side_on_plane    = n.cross(forward_on_plane).normalized()


	var old_v      = character.velocity
	var normal_spd = old_v.dot(n)
	var planar_v   = old_v - n * normal_spd
	var planar_spd = planar_v.length()
	if planar_spd < 0.001:
		return

	var inward_side = drift_dir * side_on_plane 

	var blend = clamp(pull_and_yaw * delta, 0.0, 1.0)
	var planar_dir = planar_v / planar_spd
	var new_dir    = planar_dir.lerp(inward_side, blend).normalized()
	
	var side_force_strength := 5.0
	var lateral_force_vec = side_on_plane * side_force_strength * -drift_dir
	
	var new_planar_v = new_dir * planar_spd

	character.velocity = new_planar_v + n * normal_spd + (lateral_force_vec * delta)
	
	var cosθ = clamp(planar_dir.dot(new_dir), -1.0, 1.0)
	var sinθ = n.dot(planar_dir.cross(new_dir))
	var delta_angle = atan2(sinθ, cosθ)

	var q = Quaternion(n, delta_angle)
	var b = character.global_transform.basis
	character.global_transform.basis = (Basis(q) * b)
	
# drifting becomes more effective at higher speeds
func _scale_drift_yaw_to_speed(character: Character, delta) -> float:
	var starting_yaw_rate := 1.3
	var max_yaw_rate      := 2.2
	var min_carve_frac    := 0.2
	var hvel = ti.get_hvel_relative_to_surface(character, ti.grays)

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
	var max_hold_time = 0.4
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
	
	var t = _inward_drift_timer / max_hold_time
	var applied_yaw = lerp(starting_yaw_rate, max_yaw, t)

	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n
	
	var angle = drift_dir * applied_yaw * delta
	var q = Quaternion(n, angle)
	var b = character.global_transform.basis
	character.global_transform.basis = (Basis(q) * b).orthonormalized()
	

var drift_vel_blend := 3.0
func _apply_inward_drift_velocity_blend(character: Character, delta: float) -> void:
	# slope normal
	var n = ti.get_ground_normal( ti.grays)

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

	var new_hvel = new_dir * speed

	character.velocity = new_hvel + n * norm_spd


# increase the speed of whever the current velocity is agnositic to direction
func _accelerate_drift(character: Character, delta: float) -> void:
	var hvel = ti.get_hvel_relative_to_surface(character,  ti.grays)
	var speed = hvel.length()

	var delta_speed = HelperFunctions.calc_forward_accel_delta(character, speed, delta)
	
	var travel_dir = hvel / speed

	character.velocity += travel_dir * delta_speed

func _decelerate_drift(character: Character, delta: float) -> void:
	var decel_rate := 10.0


	var n = ti.get_ground_normal(ti.grays)
	if n.dot(Vector3.UP) < 0:
		n = -n

	var old_v       = character.velocity
	var normal_spd  = old_v.dot(n)      
	var planar_v    = old_v - n * normal_spd    


	var speed       = planar_v.length()
	if speed < 0.001:
		return 

	var decel_amt   = min(decel_rate * delta, speed)
	
	var dir         = planar_v.normalized()
	var new_planar  = dir * (speed - decel_amt)

	# re‑assemble elocity
	character.velocity = new_planar + n * normal_spd

# probably a slightly unessecary guard given i dont bleed drift speed
# does guard for people trying to deccel tho so screw it

func _exit_at_20_mph(character: Character):
	var mph = HelperFunctions.get_mph(character)
	
	if mph <= 20:
		Input.action_release("jump_drift")
