extends Node3D

@export var countdown_label_path: NodePath
@onready var countdown_label: Label = get_node(countdown_label_path)

@export var countdown_time: int = 3
@export var label_font_size: int = 128

var race_started := false

func _ready():
	_style_label()
	_disable_racers()
	_start_countdown()

func _style_label() -> void:
	countdown_label.visible = true
	countdown_label.modulate.a = 0.0
	countdown_label.scale = Vector2.ONE

	countdown_label.add_theme_color_override("font_color", Color.hex(0x702501FF)) # fill
	countdown_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.55))
	countdown_label.add_theme_constant_override("shadow_offset_x", 3)
	countdown_label.add_theme_constant_override("shadow_offset_y", 3)
	countdown_label.add_theme_constant_override("shadow_as_outline", 0)

func _disable_racers():
	for body in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("ai"):
		body.set_physics_process(false)
		if body.has_method("set_input_enabled"):
			body.set_input_enabled(false)

func _enable_racers():
	for body in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("ai"):
		if body.has_method("set_input_enabled"):
			body.set_input_enabled(true)
		body.set_physics_process(true)

func _start_countdown() -> void:
	# 3,2,1
	for i in range(countdown_time, 0, -1):
		await _pop_text(str(i), 0.35, 0.65)

	# GO!
	await _pop_text("GO!", 0.35, 0.65)
	# Give the UI frame to settle, then enable racers
	await get_tree().physics_frame
	_enable_racers()
	race_started = true

	# Let "GO!" linger briefly then hide
	await get_tree().create_timer(0.5).timeout
	countdown_label.visible = false

func _pop_text(text: String, fade_in_time := 0.35, hold_time := 0.65) -> void:
	countdown_label.text = text
	# start slightly larger & transparent
	countdown_label.modulate.a = 0.0
	countdown_label.scale = Vector2(1.25, 1.25)

	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(countdown_label, "modulate:a", 1.0, fade_in_time)
	tw.parallel().tween_property(countdown_label, "scale", Vector2.ONE, fade_in_time)
	await tw.finished
	await get_tree().create_timer(hold_time).timeout
