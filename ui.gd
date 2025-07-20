extends CanvasLayer
@export var player_path: NodePath
@onready var _player: Character = get_node(player_path).get_child(0)
var _speed_label: RichTextLabel

func _ready():
	_speed_label = $SpeedLabel
	

func _process(delta):
	if _player and _speed_label:
		var mph = _player.get_mph(_player)
		_speed_label.text = "%0.2f mph" % mph
