extends Node

const PAUSE_MENU_SCENE := preload("res://scenes/ui/menus/pause.tscn")
var menu: Control

func _ready():
	menu = PAUSE_MENU_SCENE.instantiate()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.hide()
	if get_tree():  # ensure we’re in the scene tree
		get_tree().root.add_child(menu)

	# connect signals safely (avoid errors if script changed)
	if menu.has_signal("resume_requested"):
		menu.resume_requested.connect(_on_resume)
	if menu.has_signal("quit_requested"):
		menu.quit_requested.connect(_on_quit)

func toggle_pause():
	if menu == null:
		push_error("Pause menu not loaded.")
		return

	# Ensure it’s in the tree (in case it was freed or not added yet)
	if not menu.get_parent() and get_tree():
		get_tree().root.add_child(menu)

	if get_tree() and get_tree().paused:
		_on_resume()
	else:
		if menu.has_method("show_menu"):
			menu.show_menu()
		else:
			menu.show()
			if get_tree():
				get_tree().paused = true

func _on_resume():
	if menu == null:
		return
	if menu.has_method("hide_menu"):
		menu.hide_menu()
	else:
		menu.hide()
		if get_tree():
			get_tree().paused = false

func _on_quit():
	if get_tree():
		get_tree().quit()
