extends Node3D

@export var player_path: NodePath
@onready var _player = get_node(player_path) as Character

@export var smoothing_speed := 4.0   # tweak this higher → snappier, lower → more floaty
var _camera_yaw := 0.0               # remember the last smoothed yaw

# works for now but obviously coupled to velocity so I am manageing vel around it
func _process(delta):
	# get the board’s horizontal velocity
	var hvel = Vector3(_player.velocity.x, 0, _player.velocity.z)
	if hvel.length() < 0.1:
		return  # too slow to care about direction
	var target_yaw = atan2(-hvel.x, -hvel.z)
	# smoothly move our cached yaw toward it
	_camera_yaw = lerp_angle(_camera_yaw, target_yaw, smoothing_speed * delta)
	# apply
	global_rotation.y = _camera_yaw
