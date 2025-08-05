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
	var _max_acceleration := 12.0
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

static func get_horizontal_speed(character: Character) -> float:
	return character.velocity.length()

static func get_side_axis(character: Character) -> Vector3:
	# basis.x is the local +X axis in world coords
	return character.global_transform.basis.x.normalized()

static func get_mph(character: Character) -> float:
	return character.velocity.length() * 2.23694

static func sum(arr: Array, initial = null) -> Variant:
	var total = 0
	if initial != null:
		total = initial
	else:
		if typeof(arr[0]) == TYPE_VECTOR3:
			total = Vector3.ZERO
		else:
			total = 0
	for v in arr:
		total += v
	return total
