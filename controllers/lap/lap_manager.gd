extends Node
class_name LapManager

# Stores lap count per body
var lap_counts: Dictionary = {} # body -> lap number
var checkpoints : Array[Node] = []

@export var end_menu_scene: PackedScene   # assign your PlayAgain/EndMenu .tscn in Inspector
var _race_over := false

signal lap_completed(body: Node, lap_count: int)

func _ready():
	checkpoints = get_tree().get_nodes_in_group("lap_checkpoint")
	for c in checkpoints:
		c.get_child(0).connect("c_pass", _on_checkpoint_crossed)

	var start_line = get_tree().get_nodes_in_group("start_line")
	start_line[0].get_child(0).connect("body_entered", _on_start_line_crossed)

func _on_checkpoint_crossed(body: Node, checkpoint: Area3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("ai")):
		return
	checkpoint.passed[body] = true   # per-body pass dict

func _on_start_line_crossed(body: Node) -> void:
	if not (body.is_in_group("player") or body.is_in_group("ai")):
		return
	if not lap_counts.has(body):
		lap_counts[body] = 1

	# Check if *this body* passed all checkpoints
	for c in checkpoints:
		if not c.get_child(0).passed.get(body, false):
			return
		else:
			c.get_child(0).reset_pass(body)

	# Increment lap count
	lap_counts[body] += 1
	emit_signal("lap_completed", body, lap_counts[body])

	# Race complete?
	if _race_over:
		return
	if lap_counts[body] >= 4:
		_race_over = true
		var result: String
		if body.is_in_group("player"):
			result = "You Win!"
		else:
			result = "You Lose!"
		_show_end_menu(result)

func _show_end_menu(result_text: String) -> void:
	if end_menu_scene == null:
		push_error("end_menu_scene not assigned")
		return
	var menu := end_menu_scene.instantiate()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(menu)
	if menu.has_method("set_result_text"):
		menu.set_result_text(result_text)
	get_tree().paused = true
