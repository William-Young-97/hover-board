extends Node3D

@export var player_path: NodePath
@onready var _player = get_node(player_path) as Character

@export var terrain_interactions_path: NodePath
@onready var _terrain_interactions = get_node(terrain_interactions_path) as TerrainInteractions

@export var smoothing_speed := 4.0   # tweak this higher → snappier, lower → more floaty
var _camera_yaw := 0.0               # remember the last smoothed yaw
var _camera_pitch := 0.0 
var _camera_roll := 0.0 
# works for now but obviously coupled to velocity so I am manageing vel around it
func _process(delta):
	# get the board’s horizontal velocity
	var hvel = _terrain_interactions.get_hvel_relative_to_surface(_player, _terrain_interactions.arays)
	if hvel.length() < 0.1:
		return  # too slow to care about direction
	var target_yaw = atan2(-hvel.x, -hvel.z)
	# smoothly move our cached yaw toward it
	_camera_yaw = lerp_angle(_camera_yaw, target_yaw, smoothing_speed * delta)
	# apply to world space
	self.global_rotation.y = _camera_yaw
	# kill local rotation so we are fixed for slopes

	var loc_rot = rotation
	var flat_smoothing_speed = 1.3
	loc_rot.x = lerp_angle(loc_rot.x, 0.0, flat_smoothing_speed * delta)
	loc_rot.z = lerp_angle(loc_rot.z, 0.0, flat_smoothing_speed * delta)
	rotation = loc_rot
