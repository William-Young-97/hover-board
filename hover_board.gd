# HoverboardRigid.gd
extends RigidBody3D

@export var hover_height  : float = 2.0    # meters above ground
@export var spring_k      : float = 200.0  # spring stiffness
@export var damper_d      : float = 100.0  # spring damping
@export var engine_force  : float = 0.00000000000000000000000000001 # N of forward thrust
@export var turn_torque   : float =    2.0 # Nm of yaw torque
@export var jump_impulse  : float =  300.0 # upward impulse on jump

@onready var rays = get_tree().get_nodes_in_group("raycasts")

var is_airborne := false

func _ready():
	custom_integrator = true
	gravity_scale     = 1.0
	linear_damp       = 1.0
	angular_damp      = 2.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt     = state.step
	var pos    = state.transform.origin
	var vel    = state.get_linear_velocity()

	# — Collect hit data —
	var sum_pos   := Vector3.ZERO
	var sum_norm  := Vector3.ZERO
	var count     := 0

	for r in rays:
		r.force_raycast_update()
		if not r.is_colliding(): continue
		sum_pos  += r.get_collision_point()
		sum_norm += r.get_collision_normal()
		count   += 1

	if count > 0:
		# average ground point & normal
		var ground_pt = sum_pos / count
		var ground_n  = sum_norm.normalized()

		# compute distance along normal from board to ground
		var to_board = pos - ground_pt
		var dist     = to_board.dot(ground_n)

		# spring–damper along that normal
		var error  = hover_height - dist
		var vel_n  = vel.dot(ground_n)
		var lift_f = spring_k * error - damper_d * vel_n

		# apply force at center (could also spread to each ray)
		state.apply_central_force(ground_n * lift_f)

	# — Jump handling —
	if Input.is_action_just_pressed("jump") and not is_airborne:
		state.apply_central_impulse(Vector3.UP * jump_impulse)
		is_airborne = true

	# — Gravity when airborne —
	if is_airborne:
		var g  = ProjectSettings.get_setting("physics/3d/default_gravity")
		var W  = mass * g
		state.apply_central_force(Vector3.DOWN * W)

		# detect landing by seeing if any ray is colliding *and* normal is sufficiently close to world-up
		for r in rays:
			if r.is_colliding() and r.get_collision_normal().dot(Vector3.UP) > 0.5:
				is_airborne = false
				break

	# Replace in your integrator:

# — Drive forward/back — 
	var accel = Input.get_action_strength("forward") - Input.get_action_strength("back")
	if accel != 0.0:
		var fwd = -state.transform.basis.z
		state.apply_central_force(fwd * engine_force * accel)

# — Steering — 
	var steer = Input.get_action_strength("right") - Input.get_action_strength("left")
	if steer != 0.0:
		state.apply_torque(Vector3.UP * turn_torque * steer)
