extends State
class_name DriftState

# TODO
# guard against players dobule drifting in the same direction
# PROBABLY NEEDS TO HAPPEN IN INPUT CONTROLLER
# can also penalise it in my boost sytstem as it counts as not following a boost through

var state_name = "drifting"
var _inward_drift_timer = 0

func enter(character: Character, delta) -> void:
	pass
	
func exit(character: Character, delta) -> void:
	pass
	# could add a timer here and when it hits 2 secs
	# allow them to drift in the same dir again
func update(character: Character, delta) -> void:
	_exit_at_10_mph(character)
	_apply_drift(character, delta)

	if character.input_forward:
		_accelerate_drift(character, delta)
	if character.input_backward:
		_decelerate_drift(character, delta)
		
func on_trigger(character: Character, trigger: int, delta: float) -> State:
	match trigger:
		Events.Trigger.END_DRIFT:
			character.left_drift = false
			character.right_drift = false
			return GroundState.new()
	return null

# this method will switch to handle left vs right drift
func _apply_drift(character: Character, delta):
	# this will probably benefit from being some kind of scaled ratio
	var outward_push_strength := 1.5 
	var side = HelperFunctions.get_side_axis(character)
	
	if character.left_drift:
		if character.input_left:
			character.drift_dir = 1
			var max_yaw = _scale_drift_yaw_to_speed(character, delta)
			_scale_yaw_to_input(character, delta, max_yaw, character.drift_dir)
			_apply_inward_drift_velocity_blend(character, delta)
		elif character.input_right:
			character.drift_dir = 1
			_inward_drift_timer = 0
			_apply_outward_drift(character, character.drift_dir, delta)
		else:
			_inward_drift_timer = 0
			
	elif character.right_drift:
		if character.input_right:
			character.drift_dir = -1
			var max_yaw = _scale_drift_yaw_to_speed(character, delta)
			_scale_yaw_to_input(character, delta, max_yaw, character.drift_dir)
			_apply_inward_drift_velocity_blend(character, delta)
		elif character.input_left:
			character.drift_dir = -1
			_inward_drift_timer = 0

			_apply_outward_drift(character, character.drift_dir, delta)
		else:
			_inward_drift_timer = 0
			
func _apply_outward_drift(character: Character, drift_dir: int, delta: float) -> void:
	var shift_rate := 0.05 # fraction of forward speed per second to reassign
	var forward =  _terrain_interactions.get_forward_direction_relative_to_surface(character)
	var side = HelperFunctions.get_side_axis(character)

	# split current forward & lateral speeds
	var hvel = _terrain_interactions.get_hvel_relative_to_surface(character)
	var fwd_spd = forward.dot(hvel)
	var lat_spd = side.dot(hvel)

	# compute how much to shift this frame
	var shift = min(fwd_spd, fwd_spd * shift_rate * delta)
	
	# remove from forward, add (with sign) to lateral
	fwd_spd -= shift
	lat_spd += drift_dir * shift
	
	var new_hvel = forward * fwd_spd + side * lat_spd
	character.velocity.x = new_hvel.x
	character.velocity.z = new_hvel.z
	

# drifting becomes more effective at higher speeds
func _scale_drift_yaw_to_speed(character: Character, delta) -> float:
	var starting_yaw_rate := 1.0 # radians/sec when barely carving
	var max_yaw_rate      := 1.9 # radians/sec when fully carving
	var min_carve_frac    := 0.2 
	var hvel = _terrain_interactions.get_hvel_relative_to_surface(character)
	var speed_frac = clamp(hvel.length() / character.top_speed, 0.0, 1.0)
	var carve_scale = lerp(min_carve_frac, 1.0, sqrt(speed_frac))
	var out_yaw_rate = lerp(starting_yaw_rate, max_yaw_rate, carve_scale)
	
	return out_yaw_rate
	
# build our yaw based on time input held
func _scale_yaw_to_input(character: Character, delta, max_yaw,  drift_dir):
	# will decide later if i like having speed scaling feature of if it throws peaople off
	# max_yaw = 1.8
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
	
	character.rotation.y += drift_dir * applied_yaw * delta
	
var drift_vel_blend := 5
func _apply_inward_drift_velocity_blend(character, delta):
	var hvel = _terrain_interactions.get_hvel_relative_to_surface(character)
	var speed = hvel.length()
	if speed < 0.001:
		return 

	var curr_yaw   = atan2(hvel.x, hvel.z)
	var target_yaw = character.rotation.y   # new nose heading

	# blend toward the nose—scaled by delta so it's frame‑rate independent
	var blend_amount = clamp(drift_vel_blend * delta, 0, 1)
	var new_yaw = lerp_angle(curr_yaw, target_yaw, blend_amount)

		# 1) get your flat, yaw‐only direction:
	var flat_dir = Vector3( sin(new_yaw), 0, cos(new_yaw) ).normalized()

	# 2) fetch & orient the surface normal upward:
	var n = _terrain_interactions.get_y_relative_to_surface()

	# 3) project flat_dir onto the plane (i.e. remove any component along n):
	var dir = (flat_dir - n * flat_dir.dot(n)).normalized()

	# 4) re‑apply speed:
	var new_hvel = dir * speed
	character.velocity.x = new_hvel.x
	character.velocity.y = character.velocity.y  # preserve any vertical motion
	character.velocity.z = new_hvel.z

# possible I could decompose base accel and drif tmore for better reuse
func _accelerate_drift(character: Character, delta: float) -> void:
	var hvel = _terrain_interactions.get_hvel_relative_to_surface(character)
	var speed = hvel.length()

	var delta_speed = HelperFunctions.calc_forward_accel_delta(character, speed, delta)
	
	var travel_dir = hvel / speed

	character.velocity += travel_dir * delta_speed

func _decelerate_drift(character: Character, delta: float) -> void:
	var _deceleration_rate := 10.0
	
	var side = HelperFunctions.get_side_axis(character)
	var forward = _terrain_interactions.get_forward_direction_relative_to_surface(character)

	var hvel = _terrain_interactions.get_hvel_relative_to_surface(character)
	var speed = hvel.length()

	var decel_amt = min(_deceleration_rate * delta, speed)

	var dir = hvel.normalized()
	var new_speed = speed - decel_amt
	
	var new_hvel = dir * new_speed

	character.velocity = new_hvel

# probably a slightly unessecary guard given i dont bleed drift speed
# does guard for people trying to deccel tho so screw it
func _exit_at_10_mph(character: Character):
	var mph = HelperFunctions.get_mph(character)
	
	if mph <= 20:
		Input.action_release("jump_drift")
		
