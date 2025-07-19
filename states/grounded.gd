extends State
class_name GroundState

var state_name = "grounded"
	
func update(character: Character, delta: float) -> void:

	character.apply_character_gravity(delta)
	character.horizontal_clamp()
	character.move_and_slide()
	character.apply_hover(delta)
	character.clear_lateral_velocity()
	
	if character.input_forward:
		character.accelerate(delta)
	elif character.input_backward:
		character.decelerate(delta)
	else:
		character.tend_speed_to_zero(delta)

	character.steering(delta, character.input_turn)

func on_trigger(character: Character, trigger: int) -> State:
	match trigger:
		Triggers.Actions.JUMP:
			if character.is_grounded():
				return ManualJumpState.new()
	return null
