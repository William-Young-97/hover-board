extends CanvasLayer
@export var player_path: NodePath
@onready var _player: Character = get_node(player_path).get_child(0)

@export var lap_manager_path: NodePath
@onready var _lap_manager: LapManager = get_node(lap_manager_path)

var _speed_label: RichTextLabel
var _lap_label: RichTextLabel

func _ready():
	_lap_manager.connect("lap_completed", _on_lap_completed)
	_speed_label = $SpeedLabel
	_lap_label = $LapLabel
	_lap_label.text = "Lap: %d/3" % _lap_manager.lap_counts.get(_player, 1)
	
func _physics_process(delta):
	if _player and _speed_label:
		var mph = HelperFunctions.get_mph(_player)
		_speed_label.text = "%0.2f mph" % mph

func _on_lap_completed(body: Node, new_lap_count: int) -> void:
	if body != _player:
		return
	_lap_label.text = "Lap: %d/3" % new_lap_count
	print("LAP COMPLETE")
