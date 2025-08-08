extends Area3D

var passed = false

signal c_pass(body: Character, checkpoint: Area3D)

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

# watch out for AI wiping this. Will need to handle that too
func _on_body_entered(body: Character) -> void:
	emit_signal("c_pass", body, self)
