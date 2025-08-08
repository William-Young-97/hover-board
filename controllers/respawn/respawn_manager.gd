extends Node
# Have to make sure death and respawn objects are added to there groups

# these get filled in on _ready()
var respawn_points : Array[Node] = []
var death_zones    : Array[Node] = []

# the one checkpoint we're teleporting back to
var active_point: Area3D = null

func _ready():
	respawn_points = get_tree().get_nodes_in_group("RespawnPoint")
	death_zones    = get_tree().get_nodes_in_group("DeathZone")

	for p in respawn_points:
		p.get_child(0).connect("active_point", _on_checkpoint_entered)
	for d in death_zones:
		d.get_child(0).connect("body_entered",_on_deathzone_entered)

func _on_checkpoint_entered(body: Character, checkpoint: Area3D) -> void:
	if not body.is_in_group("player"): return
	active_point = checkpoint

func _on_deathzone_entered(body: Node) -> void:
	if not body.is_in_group("player"): return
	_respawn_player(body)

func _respawn_player(player: Character) -> void:
	if not active_point:
		push_error("No active respawn point!")
		return

	var t = active_point.get_child(0).global_transform

	player.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)

	# zero out motion
	player.velocity = Vector3.ZERO

	# force  GroundState
	var new_state = GroundState.new()
	player.load_and_configure_next_state(new_state)
