extends State
class_name DriftingState
# TODO
# 1
# blend outward drift to nose a bit

# 2
# Add roll to the body and keep ray castrs down to really sell the drift more

# 3
# Revist outward drift force? what can i scale it to determine it?
# 4
# mini game system?  
 
var state_name = "drifting"
var inward_drift_timer = 0

func enter(character: Character, delta) -> void:
	pass

func exit(character: Character, delta) -> void:
	pass
	
func update(character: Character, delta) -> void:
	# normal in–air physics
	character.apply_character_gravity(delta)
	character.move_and_slide()
	character.apply_hover(delta)
	_apply_drift(character, delta)


func on_trigger(character: Character, trigger: int) -> State:
	match trigger:
		Triggers.Actions.END_DRIFT:
			character.left_drift = false
			character.right_drift = false
			return GroundState.new()
	return null

# this method will switch to handle left vs right drift
func _apply_drift(character: Character, delta):
	# this will probably benefit from being some kind of scaled ratio
	var outward_push_strength := 1.5 
	var side = character.get_side_axis()
	var dir = 0
	
	if character.left_drift:
		if character.input_left:
			dir = 1
			var max_yaw = _scale_drift_yaw_to_speed(character, delta)
			_scale_yaw_to_input(character, delta, max_yaw, dir)
			_apply_inward_drift_velocity_blend(character, delta)
		elif character.input_right:
			inward_drift_timer = 0
			character.velocity += side *  outward_push_strength * delta
		else:
			inward_drift_timer = 0
			
	elif character.right_drift:
		if character.input_right:
			dir = -1
			var max_yaw = _scale_drift_yaw_to_speed(character, delta)
			_scale_yaw_to_input(character, delta, max_yaw, dir)
			_apply_inward_drift_velocity_blend(character, delta)
		elif character.input_left:
			inward_drift_timer = 0
			# need to belnd towards nose here too to maintain arc
			character.velocity += -side *  outward_push_strength * delta
		else:
			inward_drift_timer = 0
			
# drifting becomes more effective at higher speeds
func _scale_drift_yaw_to_speed(character: Character, delta) -> float:
	var starting_yaw_rate := 1.0 # radians/sec when barely carving
	var max_yaw_rate      := 1.8 # radians/sec when fully carving
	var min_carve_frac    := 0.2 
	var hvel      = Vector3(character.velocity.x, 0, character.velocity.z)
	var speed_frac = clamp(hvel.length() / character.top_speed, 0.0, 1.0)
	var carve_scale = lerp(min_carve_frac, 1.0, sqrt(speed_frac))
	var out_yaw_rate = lerp(starting_yaw_rate, max_yaw_rate, carve_scale)
	
	return out_yaw_rate
	
# build our yaw based on time input held
func _scale_yaw_to_input(character: Character, delta, max_yaw, dir):
	# will decide later if i like having speed scaling feature of if it throws peaople off
	# max_yaw = 1.8
	var max_hold_time = 0.5
	var starting_yaw_rate := 1.3
	var inward_held := false
	
	if dir == 1:
		inward_held = character.input_left
	elif dir == -1:
		inward_held = character.input_right

	
	if inward_held:
		inward_drift_timer = min(inward_drift_timer + delta, max_hold_time)
	else:
		inward_drift_timer = 0
	
	var t = inward_drift_timer / max_hold_time # 0→1 over that second
	var applied_yaw = lerp(starting_yaw_rate, max_yaw, t)
	character.rotation.y += dir * applied_yaw * delta
	
var drift_vel_blend := 5
func _apply_inward_drift_velocity_blend(character, delta):
	var hvel = Vector3(character.velocity.x, 0, character.velocity.z)
	var speed = hvel.length()
	if speed < 0.001:
		return 

	var curr_yaw   = atan2(hvel.x, hvel.z)
	var target_yaw = character.rotation.y   # ew nose heading

	# blend toward the nose—scaled by delta so it's frame‑rate independent
	var blend_amount = clamp(drift_vel_blend * delta, 0, 1)
	var new_yaw = lerp_angle(curr_yaw, target_yaw, blend_amount)

	# rebuild horizontal velocity at the same speed
	var dir = Vector3( sin(new_yaw), 0, cos(new_yaw) )
	var new_hvel = dir * speed

	character.velocity.x = new_hvel.x
	character.velocity.z = new_hvel.z
