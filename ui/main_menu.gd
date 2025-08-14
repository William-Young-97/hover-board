extends Control

@export var race_scene_path: String = "res://scenes/maps/track_2.tscn"

func _ready():
	$CenterContainer/VBoxContainer/Play.connect("pressed", _on_play_pressed)
	$CenterContainer/VBoxContainer/Quit.connect("pressed", _on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(race_scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
