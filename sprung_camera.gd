extends Camera3D

@export var board_pivot_path: NodePath  # a child‐Node3D of your board at just the right “follow” position
@export var look_target_path: NodePath  # usually the board itself (so you look at its center)

var _pivot: Node3D
var _look: Node3D

func _ready():
	_pivot = get_node(board_pivot_path)
	_look  = get_node(look_target_path)
	if not _pivot or not _look:
		push_error("Camera: missing pivot or look target!")

func _process(delta):
	# 1) follow the pivot’s world‐space position:
	global_position = _pivot.global_position

	# 2) lock yourself upright (zero out roll/pitch/yaw so you never tilt/rotate with the board):
	global_rotation = Vector3.ZERO

	# 3) aim at the board:
	look_at(_look.global_position, Vector3.UP)
