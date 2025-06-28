class_name SprungCamera3D
extends Camera3D

# What's the big idea?

# We need to create a sprung camera that moves in all axis
# we'll begin by assuming that vertical and longituidnal are stable
# And focus on the movement of the lateral axis

# 

@export var lateral_factor     : float   = 1.0
@export var vertical_factor    : float   = 1.0
@export var longitudinal_factor: float   = 1.0

# Spring parameters
@export var convergance := 10.0
@export var momentum := 1.0
@export var damping := 10.0
@export var turn_inertia_scale := 2.0  

var _turn_inertia := 0.0
var _last_yaw := 0.0

# Internal state
var _velocity := Vector3.ZERO
var _camera_target_position: Node3D
var _board: Node3D

func _ready():
	# CameraTargetPosition is this node's parent
	_camera_target_position = get_parent()
	_board = _camera_target_position.get_parent().get_parent()
	
#func _physics_process(delta):
	#self.update_camera(delta)
	#
#func update_camera(delta):
	#var current_yaw = _board.rotation.y
	#var yaw_delta   = wrapf(current_yaw - _last_yaw, -PI, PI)
	#_last_yaw = current_yaw
	#
	## 1) integrate into turn inertia
	##    positive yaw_delta = turning right, negative = left
	#_turn_inertia += yaw_delta * turn_inertia_scale
	#
	## 2) carry inertia forward and apply damping
	#_turn_inertia = lerp(_turn_inertia, 0.0, damping * delta) * momentum
	#
	## 3) build your camera target as usual…
	#var basis = _camera_target_position .global_transform.basis
	#var base_pos = _camera_target_position .global_transform.origin
	#var desired = base_pos
	##desired += basis.y * _camera_target_position.y * vertical_factor
	##desired += basis.z * _camera_target_position.z * longitudinal_factor
	##
	### 4) add the lateral swing from turn inertia
	##desired += basis.x * _turn_inertia
	#
	
