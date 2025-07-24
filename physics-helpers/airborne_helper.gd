# AirborneHelper.gd
extends Node
class_name AirborneHelper
# bugged giving forward speed when it should repoject entery velocity
@export var air_yaw_speed := 0.7

func steer(character: CharacterBody3D, turn_input: float, delta: float) -> void:
	var yaw_delta := turn_input * air_yaw_speed * delta
	character.rotate_y(yaw_delta)
	var speed = character.velocity.length()
	character.velocity = -character.transform.basis.z * -speed
