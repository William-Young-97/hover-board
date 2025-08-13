extends Node3D

@export var player_path: NodePath
@onready var _player = get_node(player_path) as Character

@export var terrain_interactions_path: NodePath
@onready var _terrain_interactions = get_node(terrain_interactions_path) as TerrainInteractions


@export var smoothing_speed := 4.0   # tweak this higher → snappier, lower → more floaty
var _camera_yaw := 0.0               # remember the last smoothed yaw
var _camera_pitch := 0.0 
var _camera_roll := 0.0 

var _is_looking := false
var _desired_yaw = 0.0

func _ready() -> void:
	pass
# works for now but obviously coupled to velocity so I am manageing vel around it

func _process(delta):
	#  Compute desired “forward” (−Z) and “up” (+Y) in world‑space:
	var hvel = _terrain_interactions.get_hvel_relative_to_surface(_player, _terrain_interactions.grays)
	if hvel.length() < 0.1:
		return  # too slow to care
	
	# Forward: opposite the motion, flattened onto horizontal:
	var flat_forward = (-hvel).normalized()
	
	# Up: whichever way the board’s ground normal points:
	var up = _terrain_interactions.get_ground_normal(_terrain_interactions.grays)
	if up.dot(Vector3.UP) < 0:
		up = -up
	
	# Orthonormalize those into a full Basis:
	#    - X_axis = (forward × up).normalized()
	#    - Recompute forward = (up × X_axis).normalized()
	var x_axis = up.cross(flat_forward).normalized()
	var z_axis = x_axis.cross(up).normalized()  # this is your “forward”
	var target_basis = Basis(x_axis, up, z_axis)
	
	# 3) Slerp current pivot‐basis → target_basis:
	var current_q = Quaternion(global_transform.basis)
	var target_q  = Quaternion(target_basis)
	var t = clamp(smoothing_speed * delta, 0.0, 1.0)
	var new_q = current_q.slerp(target_q, t)
	
	global_transform.basis = Basis(new_q)
