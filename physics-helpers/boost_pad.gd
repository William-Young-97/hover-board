extends Area3D
# How strong the boost should be (tweak to taste)
@export var boost_strength: float = 2000.0
# Optional cooldown so the player can’t retrigger every frame
@export var cooldown: float = 0.5

var _last_boost_time: float = -1.0

func _ready():
	# Make sure this Area3D is monitoring bodies
	monitoring = true
	# Connect the signal
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node) -> void:
	if not body is CharacterBody3D:
		return

	# — you still want your cooldown check here —

	# 1) get a usable surface normal
	var n = body.get_floor_normal()
	if not body.is_on_floor() or n == Vector3.ZERO:
		n = Vector3.UP
	n = n.normalized()

	# 2) decompose current velocity
	var old_v      = body.velocity
	var normal_spd = old_v.dot(n)               # speed into/out of the slope
	var planar_v   = old_v - n * normal_spd     # the part sliding along the slope
	var planar_spd = planar_v.length()

	# if you’re basically stationary on that slope, pick the character’s facing as planar direction:
	if planar_spd < 0.001:
		var raw_fwd = -body.global_transform.basis.z.normalized()
		planar_v = (raw_fwd - n * raw_fwd.dot(n)).normalized()
		planar_spd = 0.0

	# 3) boost only the planar component
	planar_spd += boost_strength

	# 4) rebuild the final velocity
	body.velocity = planar_v.normalized() * planar_spd + n * normal_spd

	print("Boosted planar speed to ", planar_spd, "on normal ", n)
