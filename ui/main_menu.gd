extends Control

@export var race_scene_path: String = "res://scenes/RaceTrack.tscn"

@onready var _label: Label = $Result
@onready var _play:  Button = $CenterContainer/VBoxContainer/PlayAgain
@onready var _quit:  Button = $CenterContainer/VBoxContainer/Quit

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play.pressed.connect(_on_play_again)
	_quit.pressed.connect(_on_quit)

func set_result_text(t: String) -> void:
	_label.text = t

func _on_play_again() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(race_scene_path)



func _on_quit() -> void:
	get_tree().quit()
