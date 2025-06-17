# HoverboardRigid.gd
extends RigidBody3D

@export var hover_height := 2.0   
@export var speed := 5.0 
@export var turn_speed := 2.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	get_input(delta)

func get_input(delta):
	
	var forward = Input.is_action_pressed("forward")
	var backwards = Input.is_action_pressed("back")
	var left = Input.is_action_pressed("left")
	var right = Input.is_action_pressed("right")
	
	var rays = get_tree().get_nodes_in_group("raycasts")
	
	var forward_dir  = -global_transform.basis.z
	var backward_dir =  global_transform.basis.z
	
	for ray in rays:
		# Give forward and backward velocity
		if ray.is_colliding() and forward:
			apply_central_force(forward_dir * speed)
		if ray.is_colliding() and backwards:
			apply_central_force(backward_dir * speed)
		# Give left and right turn torque
		if ray.is_colliding() and left:
			rotate_y(turn_speed * delta)
		if ray.is_colliding() and right:
			rotate_y(-turn_speed * delta)



func look_follow(
	state: PhysicsDirectBodyState3D,
	transform: Transform3D,
	target_position: Vector3
) -> void:
	# 1) Pick your “forward” axis—by convention in Godot + many 3D models it's -Z
	var forward_dir: Vector3 = -transform.basis.z.normalized()
	# 2) Compute the direction to your target in world space
	var to_target: Vector3 = (target_position - transform.origin).normalized()
	# 3) Compute the angle error (always clamp to avoid NaN)
	var dot = clamp(forward_dir.dot(to_target), -1.0, 1.0)
	var angle_error = acos(dot)
	if angle_error < 0.001:
		# Already facing the right way
		state.angular_velocity = Vector3.ZERO
		return
	# 4) Compute the shortest rotation axis
	var turn_axis = forward_dir.cross(to_target).normalized()
	# 5) Scale it by a turn rate (radians per second)
	var desired_angular_speed = angle_error * turn_speed
	state.angular_velocity = turn_axis * desired_angular_speed


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# e.g. face 10 units ahead along your board’s local forward:
	var look_target = global_transform.origin + (-global_transform.basis.z) * 10.0
	look_follow(state, global_transform, look_target)
