extends Control

signal resume_requested
signal quit_requested

@onready var _resume_btn: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var _quit_btn:   Button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_btn.pressed.connect(_on_resume_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

func show_menu():
	visible = true
	if get_tree():
		get_tree().paused = true

func hide_menu():
	visible = false
	if get_tree():
		get_tree().paused = false

func _on_resume_pressed():
	emit_signal("resume_requested")

func _on_quit_pressed():
	emit_signal("quit_requested")
