# HoverboardKinematicHybrid.gd
extends CharacterBody3D
#— tuning parameters ——
@export var hover_height := 2.0   
@export var speed := 5.0 
@export var turn_speed := 2.0
@export var gravity := 5


func _physics_process(delta):
	#velocity.y -= gravity * delta
	print(velocity.y)
	get_input(delta)
	move_and_slide()

func get_input(delta):
	velocity.x = 0
	velocity.z = 0
	
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
			velocity += forward_dir * speed
		if ray.is_colliding() and backwards:
			velocity += backward_dir * speed
		# Give left and right turn torque
		if ray.is_colliding() and left:
			rotate_y(turn_speed * delta)
		if ray.is_colliding() and right:
			rotate_y(-turn_speed * delta)
			
