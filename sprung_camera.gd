class_name SprungCamera3D
extends Camera3D


# Spring parameters
@export var convergance := 10.0
@export var momentum := 1.0
@export var damping := 10.0

# Internal state
var _velocity := Vector3.ZERO
var _target: Node3D

func _ready():
	# CameraTargetPosition is this node's parent
	_target = get_parent()
	if not _target:
		push_error("SprungCamera3D: Parent CameraTargetPosition not found")

func update_camera(delta):
	var basis = _target.global_transform.basis
	var base_pos = _target.global_transform.origin
