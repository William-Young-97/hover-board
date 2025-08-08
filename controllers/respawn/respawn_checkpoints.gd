extends Area3D

signal active_point(body: Character, checkpoint: Area3D)

func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)

# watch out for AI wiping this. Will need to handle that too
func _on_body_entered(body: Character) -> void:
	emit_signal("active_point", body, self)
