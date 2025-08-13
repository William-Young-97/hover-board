extends Node
class_name RespawnManager

var respawn_points : Array[Node] = []
var death_zones    : Array[Node] = []

var active_point_player: Area3D = null
var active_point_ai: Dictionary = {}

signal respawned(body: Character)

func _ready():
	respawn_points = get_tree().get_nodes_in_group("respawn")
	death_zones    = get_tree().get_nodes_in_group("death")
	
	for p in respawn_points:
		p.get_child(0).connect("active_point", _on_checkpoint_entered)
	for d in death_zones:
		d.get_child(0).connect("body_entered", _on_deathzone_entered)

func _on_checkpoint_entered(body: Character, checkpoint: Area3D) -> void:
	if body.is_in_group("player"):
		active_point_player = checkpoint
	elif body.is_in_group("ai"):
		active_point_ai[body] = checkpoint

func _on_deathzone_entered(body: Node) -> void:
	if not (body.is_in_group("player") or body.is_in_group("ai")):
		return
	_respawn_player(body)

func _respawn_player(player: Character) -> void:
	var active_point: Area3D = null

	if player.is_in_group("player"):
		active_point = active_point_player
	elif player.is_in_group("ai"):
		if active_point_ai.has(player):
			active_point = active_point_ai[player]

	if not active_point:
		var group_name = "unknown"
		if player.is_in_group("player"):
			group_name = "player"
		elif player.is_in_group("ai"):
			group_name = "ai"

		push_error("No active respawn point for %s!" % group_name)
		return

	var t = active_point.get_child(0).global_transform
	player.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)

	player.velocity = Vector3.ZERO

	var new_state = GroundState.new()
	player.load_and_configure_next_state(new_state)

	# Only signal AI respawn
	if player.is_in_group("ai"):
		emit_signal("respawned", player)
