extends State
class_name ManualJumpState

var state_name = "manual_jump"

func enter(character: Character, delta):
	# jump off the ground and remember starting yaw for JumpRotatationState
	jump(character)                  
	character.base_jump_yaw = character.rotation.y
	
func on_trigger(character: Character, trigger: int, delta: float):
	match trigger:
		Events.Trigger.START_BANK:
			return JumpRotatationState.new()
		Events.Trigger.LANDED:
			return GroundState.new()
	
func update(character: Character, delta: float) -> State:
	return null
	
# how is this going to interact with our gravity and airbourne function
const _jump_strength := 1.5
func jump(character: Character) -> void:
	character.velocity += Vector3(0, _jump_strength ,0)
