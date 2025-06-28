extends CanvasLayer
var _hoverboard: CharacterBody3D
var _speed_label: RichTextLabel

func _ready():
	var boards = get_tree().get_nodes_in_group("hoverboard")
	_hoverboard = boards[0]
	_speed_label = $SpeedLabel
	

func _process(delta):
	if _hoverboard and _speed_label:
		var hvel = Vector3(_hoverboard.velocity.x, 0, _hoverboard.velocity.z)
		var mph = hvel.length() * 2.23694
		_speed_label.text = "%0.2f mph" % mph
