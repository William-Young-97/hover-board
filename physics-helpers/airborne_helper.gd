# AirborneHelper.gd
extends Node
class_name AirborneHelper

# turn settings
var _max_turn_rate := 1.0
var _turn_acceleration := 30.0
var _turn_damping := sqrt(_turn_acceleration)
var _turn_velocity := 0.0

func steer_airborne(character: CharacterBody3D, turn_input: float, delta: float) -> void:
	# 1) update turn velocity toward the target
	var target_rate = turn_input * _max_turn_rate
	if turn_input == 0.0:
		_turn_velocity = lerp(_turn_velocity, 0.0, _turn_damping * delta)
	else:
		var rate_diff = target_rate - _turn_velocity
		_turn_velocity += sign(rate_diff) * _turn_acceleration * delta
	_turn_velocity = clamp(_turn_velocity, -_max_turn_rate, _max_turn_rate)

	# 2) compute the yaw angle for this frame
	var yaw_delta = _turn_velocity * delta

	# 4) rotate the character
	var q = Quaternion(Vector3.UP, yaw_delta)
	character.global_transform.basis = Basis(q) * character.global_transform.basis

	# 5) rotate the planar velocity by the same yaw_delta
	var v = character.velocity
	var planar_v = Vector3(v.x, 0, v.z)
	var new_planar_v = planar_v.rotated(Vector3.UP, yaw_delta)

	# 6) rebuild the full velocity
	character.velocity = Vector3(new_planar_v.x, v.y, new_planar_v.z)
