extends Node
class_name LapManager

# Stores lap count per body
var lap_counts: Dictionary = {} # body -> lap number

var checkpoints : Array[Node] = []
signal lap_completed(body: Node, lap_count: int)

func _ready():
	checkpoints = get_tree().get_nodes_in_group("lap_checkpoint")
	for c in checkpoints:
		c.get_child(0).connect("c_pass", _on_checkpoint_crossed)

	var start_line = get_tree().get_nodes_in_group("start_line")
	start_line[0].get_child(0).connect("body_entered", _on_start_line_crossed)

# can proably get rid
func _on_checkpoint_crossed(body: Node, checkpoint: Area3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("ai")):
		return
	checkpoint.passed[body] = true

func _on_start_line_crossed(body: Node) -> void:
	if not (body.is_in_group("player") or body.is_in_group("ai")):
		return

	if not lap_counts.has(body):
		lap_counts[body] = 1

	# Check if *this specific body* has passed all checkpoints
	for c in checkpoints:
		if not c.get_child(0).passed.get(body, false):
			return
		else:
			c.get_child(0).reset_pass(body)

	# Increment lap count
	lap_counts[body] += 1
	emit_signal("lap_completed", body, lap_counts[body])
