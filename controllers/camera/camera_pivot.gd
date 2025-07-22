extends Node3D

@export var player_path: NodePath
@onready var _player = get_node(player_path) as Character

@export var terrain_interactions_path: NodePath
@onready var terrain_interactions = get_node(terrain_interactions_path) as TerrainInteractions

@export var smoothing_speed := 4.0   # tweak this higher → snappier, lower → more floaty
var _camera_yaw := 0.0               # remember the last smoothed yaw
var _camera_pitch := 0.0 
var _camera_roll := 0.0 
# works for now but obviously coupled to velocity so I am manageing vel around it
func _process(delta):
	# get the board’s horizontal velocity
	var hvel = terrain_interactions.get_hvel_relative_to_surface(_player)
	if hvel.length() < 0.1:
		return  # too slow to care about direction
	var target_yaw = atan2(-hvel.x, -hvel.z)
	# smoothly move our cached yaw toward it
	_camera_yaw = lerp_angle(_camera_yaw, target_yaw, smoothing_speed * delta)
	# apply
	self.global_rotation.y = _camera_yaw
	# self.rotation.x = 0
	# need to be able to tell if we are going up or down to orient the pitch
	# rotation
	terrain_interactions.align_roll_and_pitch_on_flats(delta, self)
	
	# print("camera pivot rotation: ", self.rotation)
