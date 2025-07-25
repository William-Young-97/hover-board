extends Node
class_name DriftHelper

var ti: TerrainInteractions
var vrc: VisualRollController

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
	# this will probably benefit from being some kind of scaled ratio
	var outward_push_strength := 1.5 
	var side = HelperFunctions.get_side_axis(character)
	
	if character.left_drift:
		vrc .direction += 1
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
		vrc .direction -= 1
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
#
func _apply_outward_drift(character: Character, drift_dir: int, delta: float) -> void:
	var shift_rate := 0.05 # fraction of forward speed per second to reassign
	var forward =  ti.get_forward_direction_relative_to_surface(character,  ti.arays)
	var side = HelperFunctions.get_side_axis(character)

	# split current forward & lateral speeds
	var hvel = ti.get_hvel_relative_to_surface(character,  ti.arays)
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
	var starting_yaw_rate := 1.0 
	var max_yaw_rate      := 1.9 
	var min_carve_frac    := 0.2 
	var hvel = ti.get_hvel_relative_to_surface(character, ti.arays)
	var speed_frac = clamp(hvel.length() / character.top_speed, 0.0, 1.0)
	var carve_scale = lerp(min_carve_frac, 1.0, sqrt(speed_frac))
	var out_yaw_rate = lerp(starting_yaw_rate, max_yaw_rate, carve_scale)
	
	return out_yaw_rate
	
# build yaw based on time input held
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

	# strip any tiny normal drift
	ti.slide_on_slopes(character,  ti.arays)

# possible I could decompose base accel and drif tmore for better reuse
func _accelerate_drift(character: Character, delta: float) -> void:
	var hvel = ti.get_hvel_relative_to_surface(character,  ti.arays)
	var speed = hvel.length()

	var delta_speed = HelperFunctions.calc_forward_accel_delta(character, speed, delta)
	
	var travel_dir = hvel / speed

	character.velocity += travel_dir * delta_speed

func _decelerate_drift(character: Character, delta: float) -> void:
	var _deceleration_rate := 10.0
	
	var side = HelperFunctions.get_side_axis(character)
	var forward = ti.get_forward_direction_relative_to_surface(character,  ti.arays)

	var hvel = ti.get_hvel_relative_to_surface(character,  ti.arays)
	var speed = hvel.length()

	var decel_amt = min(_deceleration_rate * delta, speed)

	var dir = hvel.normalized()
	var new_speed = speed - decel_amt
	
	var new_hvel = dir * new_speed

	character.velocity = new_hvel

# probably a slightly unessecary guard given i dont bleed drift speed
# does guard for people trying to deccel tho so screw it

func _exit_at_20_mph(character: Character):
	var mph = HelperFunctions.get_mph(character)
	
	if mph <= 20:
		Input.action_release("jump_drift")
