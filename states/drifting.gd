extends State
class_name DriftingState

var state_name = "drifting"

func enter(character: Character, delta) -> void:
	var drift_center_yaw = character.rotation.y

func exit(character: Character, delta) -> void:
	pass
	
func update(character: Character, delta) -> void:
	# normal in–air physics
	character.apply_character_gravity(delta)
	character.move_and_slide()
	character.apply_hover(delta)
	
	# holding a direction very slowly yaws the board in that direction
	# This change of yaw changes the direction of the boards velocity
	var drift_fine_yaw_rate := 0.5
	const MAX_FINE_BANK = deg_to_rad(15)
	print(character.base_jump_yaw)
	if character.left_drift:
		
		if character.input_left:
			character.rotation.y += drift_fine_yaw_rate * delta
		elif character.input_right:
			character.rotation.y = max(
			character.rotation.y,
			character.base_jump_yaw + MAX_FINE_BANK
			)
			character.rotation.y -= drift_fine_yaw_rate * delta
			
	elif character.right_drift:
		# figure out how much to turn this frame:
		
		var delta_yaw = 0.0
		if character.input_right:
			character.rotation.y -= drift_fine_yaw_rate * delta
		elif character.input_left:
			character.rotation.y = max(
				character.rotation.y,
				character.base_jump_yaw + -MAX_FINE_BANK,
			)
			character.rotation.y += drift_fine_yaw_rate * delta



func on_trigger(character: Character, trigger: int) -> State:
	match trigger:
		Triggers.Actions.END_DRIFT:
			character.left_drift = false
			character.right_drift = false
			return GroundState.new()
	return null
