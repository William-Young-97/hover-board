extends Area3D

# Tracks pass state per body
var passed: Dictionary = {}  # body -> bool

signal c_pass(body: Character, checkpoint: Area3D)

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Character) -> void:
	# Mark only this body as having passed
	passed[body] = true
	emit_signal("c_pass", body, self)

func reset_pass(body: Character) -> void:
	if passed.has(body):
		passed[body] = false
