extends Node
class_name HelperFunctions

# consider looking too apply singleton pattern as is stateless.
static var _instance: HelperFunctions = null

static func instance() -> HelperFunctions:
	if _instance == null:
		_instance = HelperFunctions.new()
	return _instance
	
# Physics calculation helpers
# acceleration helper func
static func calc_forward_accel_delta(character: Character, curr_fwd_spd: float, delta: float) -> float:
	var _max_acceleration := 8.0
	# how far along top speed we are
	var frac = clamp(curr_fwd_spd / character.top_speed, 0.0, 1.0)
	# quadratic taper: big accel at low speeds, zero at top
	var strength = _max_acceleration * (1.0 - frac * frac)
	return strength * delta
	
# helper function for rotating to bank
static func step_angle(current: float, target: float, max_step: float) -> float:
	# signed difference wrapped into (–π … +π]
	var diff = wrapf(target - current, -PI, PI)
	# clamp that diff to our max_step
	var step = clamp(diff, -max_step, max_step)
	return current + step

static func horizontal_clamp(character: Character) -> void:
	var hvel = get_hvel(character)
	if hvel.length() > character.top_speed:
		hvel = hvel.normalized() * character.top_speed
		character.velocity.x = hvel.x
		character.velocity.z = hvel.z
		
static func clear_lateral_velocity(character: Character) -> void:
	var side = get_side_axis(character)
	var lat = character.velocity.dot(side)
	character.velocity -= side * lat
	
static func get_forward_direction(character: Character) -> Vector3:
	# the board’s “nose” is –Z in its local basis
	var forward = -character.global_transform.basis.z.normalized()
	forward.y = 0
	return forward.normalized()

static func get_horizontal_speed(character: Character) -> float:
	var hvel = get_hvel(character)
	return hvel.length()

static func get_side_axis(character: Character) -> Vector3:
	# basis.x is the local +X axis in world coords
	return character.global_transform.basis.x.normalized()

static func get_mph(character: Character) -> float:
	var hvel = get_hvel(character)
	return hvel.length() * 2.23694

static func get_hvel(character: Character) -> Vector3:
	return Vector3(character.velocity.x, 0, character.velocity.z)
