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
	_apply_fine_drift_yaw(character, delta)


func on_trigger(character: Character, trigger: int) -> State:
	match trigger:
		Triggers.Actions.END_DRIFT:
			character.left_drift = false
			character.right_drift = false
			return GroundState.new()
	return null

func _apply_fine_drift_yaw(character: Character, delta):
	var drift_fine_yaw_rate := 0.5
	const MAX_FINE_BANK = deg_to_rad(15)

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
		if character.input_right:
			character.rotation.y -= drift_fine_yaw_rate * delta
		elif character.input_left:
			character.rotation.y = min(
				character.rotation.y,
				character.base_jump_yaw - MAX_FINE_BANK
			)
			character.rotation.y += drift_fine_yaw_rate * delta
