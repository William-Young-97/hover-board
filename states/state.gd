extends Node

class_name State

var ti: TerrainInteractions
var vrc: VisualRollController
var dh: DriftHelper
var ah: AirborneHelper

var lm: Node3D
var rm: Node3D


func enter(character: Character, delta: float):
	pass

func exit(character: Character, delta: float):
	pass
	
func update(character: Character, delta: float):
	pass

func on_trigger(character: Character, trigger: int, delta: float) -> State:
	return null
