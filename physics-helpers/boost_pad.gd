extends Area3D

@export var boost_strength: float = 300.0    # world units/second
@export var boost_duration: float = 0.5     # seconds
@export var cooldown: float = 0.1

var _last_boost_time := {}
var _active_boosts := {} # body -> time remaining

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	set_physics_process(true)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody3D):
		return

	var now := Time.get_ticks_msec() * 0.001
	if _last_boost_time.has(body) and now - _last_boost_time[body] < cooldown:
		return
	_last_boost_time[body] = now

	# Start or refresh the boost timer for this body
	_active_boosts[body] = boost_duration

func _physics_process(delta: float) -> void:
	# Apply boost effect to all active bodies
	for body in _active_boosts.keys():
		if not is_instance_valid(body):
			_active_boosts.erase(body)
			continue

		var cb := body as CharacterBody3D

		# Figure out boost direction based on current motion or facing
		var n := Vector3.UP
		if cb.is_on_floor():
			var fn := cb.get_floor_normal()
			if fn != Vector3.ZERO:
				n = fn.normalized()

		var old_v := cb.velocity
		var normal_spd := old_v.dot(n)
		var planar_v := old_v - n * normal_spd
		if planar_v.length() < 0.001:
			var raw_fwd := -cb.global_transform.basis.z.normalized()
			planar_v = (raw_fwd - n * raw_fwd.dot(n)).normalized()

		# Add boost without erasing existing momentum
		var boost_vec := planar_v.normalized() * boost_strength
		cb.velocity += boost_vec * delta

		# Countdown timer
		_active_boosts[body] -= delta
		if _active_boosts[body] <= 0.0:
			_active_boosts.erase(body)
