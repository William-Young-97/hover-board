extends State
class_name DriftingState

var state_name = "drifting"

func enter(character: Character, delta) -> void:
	pass

func exit(character: Character, delta) -> void:
	pass
	
func update(character: Character, delta) -> void:
	# normal in–air physics
	character.apply_character_gravity(delta)
	character.move_and_slide()
	character.apply_hover(delta)
	#print("left: ", character.left_drift)
	#print("right: ", character.right_drift)
	_apply_fine_drift_yaw(character, delta)
	#reproject_velocity(character)


func on_trigger(character: Character, trigger: int) -> State:
	match trigger:
		Triggers.Actions.END_DRIFT:
			character.left_drift = false
			character.right_drift = false
			return GroundState.new()
	return null

# this method will switch to handle left vs right drift
func _apply_fine_drift_yaw(character: Character, delta):
	var drift_fine_yaw_rate := 1.5
	const MAX_FINE_BANK = deg_to_rad(15)
	var outward_push_strength := 1.5 
	var side = character.get_side_axis()
	
	if character.left_drift:
		if character.input_left:
			character.rotation.y += drift_fine_yaw_rate * delta
			_apply_inward_drift_velocity_blend(character, delta)
		elif character.input_right:
			character.velocity += side *  outward_push_strength * delta
			
	elif character.right_drift:
		if character.input_right:
			character.rotation.y -= drift_fine_yaw_rate * delta
			_apply_inward_drift_velocity_blend(character, delta)
		elif character.input_left:
			character.velocity += -side *  outward_push_strength * delta

	
@export var drift_vel_blend := 5

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
