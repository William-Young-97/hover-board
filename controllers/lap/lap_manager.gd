extends Node
class_name LapManager

var lap_count : int = 1

var checkpoints : Array[Node] = []

signal lap_completed(lap_count: int)

func _ready():
	checkpoints = get_tree().get_nodes_in_group("lap_checkpoint")
	print(checkpoints)
	for c in checkpoints:
		c.get_child(0).connect("c_pass", _on_checkpoint_crossed)

	var start_line = get_tree().get_nodes_in_group("start_line")
	
	start_line[0].get_child(0).connect("body_entered", _on_start_line_crossed)

func _on_checkpoint_crossed(body: Node, checkpoint: Area3D) -> void:

	
	if not body.is_in_group("player"):
		return
	checkpoint.passed = true
	
func _on_start_line_crossed(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	
	for c in checkpoints:
		if c.get_child(0).passed == false:
			return
		else:
			c.get_child(0).passed = false
			continue
	# then the victory condition
	# if lap_count +1 == 4 then bring up victory text and replay or quit menu 
	
	lap_count += 1
	emit_signal("lap_completed", lap_count)
	
	
	
	
