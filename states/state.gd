extends Node

class_name State

var _terrain_interactions: TerrainInteractions
var _visual_roll_controller: VisualRollController

func enter(character: Character, delta: float):
	pass

func exit(character: Character, delta: float):
	pass
	
func update(character: Character, delta: float):
	pass

func on_trigger(character: Character, trigger: int, delta: float) -> State:
	return null
