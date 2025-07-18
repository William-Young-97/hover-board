extends State
class_name ManualJumpState

var state_name = "manual_jump"

func enter(character: Character, delta):
	# jump off the ground and remember starting yaw for JumpRotatationState
	character.jump()                  
	character.base_jump_yaw = character.rotation.y
	
func on_trigger(character: Character, trigger: int):
	# if input_drift_held and we have a dir we bank in air
	match trigger:
		Triggers.Actions.START_DRIFT:
			return JumpRotatationState.new()
	
func update(character: Character, delta: float) -> State:
	character.apply_character_gravity(delta)
	character.move_and_slide()
	character.apply_hover(delta)

	# assuming we've landed without a dir return to grounded (trig banking)
	if character.is_grounded() and character.velocity.y <= 0.0:
			return GroundState.new()
#
	return null
