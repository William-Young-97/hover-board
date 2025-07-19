extends State
class_name AirborneState

var state_name = "airborne"

func enter(character: Character, delta):
	pass

func update(character: Character, delta):
	character.apply_character_gravity(delta)
	# …any other in-air behavior
	character.move_and_slide()
	character.apply_hover(delta)
func on_trigger(character: Character, trigger: int) -> State:
	return null
