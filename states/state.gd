extends Node

class_name State

func enter(character: Character, delta):
	pass

func exit(character: Character, delta):
	pass
	
func update(character: Character, delta):
	pass

func on_trigger(character: Character, trigger: int) -> State:
	return null
