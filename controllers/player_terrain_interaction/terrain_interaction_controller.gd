extends Node
class_name TerrainInteractions

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var character_path: NodePath
@onready var _character: Character = get_node(character_path)


@export var fl_path: NodePath
@export var fr_path: NodePath
@export var bl_path: NodePath
@export var br_path: NodePath

@onready var fl: RayCast3D = get_node(fl_path)
@onready var fr: RayCast3D = get_node(fr_path)
@onready var bl: RayCast3D = get_node(bl_path)
@onready var br: RayCast3D = get_node(br_path)
@onready var raycasts = [fl, fr, bl, br]

var current_basis: Basis

func _ready():
	current_basis = _character.global_transform.basis
	
func _physics_process(delta: float) -> void:
	# print(_character.current_state.state_name)
	#print("is grounded check: ", is_grounded())
	#print("CHAR ROTATION: ", _character.rotation)
	#print("CHAR basis: ", _character.basis)
	mega_debugger(_character, delta)
	
	match _character.current_state.state_name:
		"grounded":
			self.apply_character_gravity(_character, delta)
			self.apply_hover(_character, delta)
			_character.move_and_slide()
			self.align_to_surface(delta)
			self.align_roll_and_pitch_on_flats(delta, _character)
			self.clear_lateral_velocity(_character)
		
			
		"manual_jump", "jump_rotation", "drifting":
			self.apply_character_gravity(_character, delta)
			self.apply_hover(_character, delta)
			_character.move_and_slide()
			self.align_to_surface(delta)
			self.align_roll_and_pitch_on_flats(delta, _character)

func mega_debugger(character: Character, delta: float) -> void:
	pass
	#print("delta time: ", delta)
	#print("percorner ray: ", get_corner_distances())
	#print("average gap: ", average_gaps(get_corner_distances()))
	#print("corner normals: ", get_corner_normals())
	#print("average surface normals: ", get_average_surface_normal())
	#print("slope steepness: ", acos(get_average_surface_normal().dot(Vector3.UP)))
	#print("surface tangent velocity: ", get_hvel_relative_to_surface(character))
	#print("real world y velocity: ", character.velocity.y)
	#print("is grounded: ", is_grounded())
	
func align_with_y(xform: Transform3D, new_y: Vector3) -> Transform3D:
	xform.basis.y = new_y
	# re‑compute X as the cross of forward(-Z) and up
	xform.basis.x = -xform.basis.z.cross(new_y).normalized()
	# orthonormalize to fix any drift
	xform.basis = xform.basis.orthonormalized()
	return xform

func align_to_surface(delta: float) -> void:
	var normals = self.get_corner_normals()
	if normals.is_empty():
		return
	
	var avg_normal = self.average_normals(normals)
	var right = HelperFunctions.get_side_axis(_character)
	var pitched_normal: Vector3 = (avg_normal - right * avg_normal.dot(right)).normalized()
	var target = align_with_y(_character.global_transform, pitched_normal)

	var interp_speed = 5.0
	var t = clamp(interp_speed * delta, 0.0, 1.0)
	_character.global_transform = _character.global_transform.interpolate_with(target, t)

func align_roll_and_pitch_on_flats(delta: float, target_node) -> void:
	if get_y_relative_to_surface() == Vector3.UP:
		# choose how fast to settle
		var smoothing_speed := 5.0
		# convert to a [0,1] factor
		var t = clamp(smoothing_speed * delta, 0.0, 1.0)
		
		# grab current world‐space Euler angles
		var rot : Vector3 = target_node.global_rotation
		
		# lerp pitch (X) and roll (Z) → 0, keep yaw (Y) untouched
		rot.x = lerp_angle(rot.x, 0.0, t)
		rot.z = lerp_angle(rot.z, 0.0, t)
		
		target_node.global_rotation = rot

# When I implement an airn=bourne state with a proper gated condition
# i should switch this to check the grounded state
func apply_character_gravity(character: Character, delta: float) -> void:
	if not self.is_grounded():
		character.velocity.y -= gravity * delta
	else:
		character.velocity.y = max(character.velocity.y, 0)


var deadzone := 0.1
var hover_height := 0.25
var hover_lerp_speed := 100.0  # how fast we snap to hover height

func apply_hover(character: CharacterBody3D, delta: float) -> void:
	# Collect normals & distances
	var normals   = get_corner_normals()
	var distances = get_corner_distances()
	if normals.is_empty() or distances.is_empty():
		return  # no ground contact

	# Average
	var avg_n   = average_normals(normals)
	var avg_dist= average_gaps(distances)  # reuse average_gaps()
	
	if avg_n.dot(Vector3.UP) < 0:
		avg_n = -avg_n
	# Compute the “ground point” directly under  avg_n
	var current_orig = character.global_transform.origin
	var ground_point = current_orig - avg_n * avg_dist

	# Target origin = ground_point + hover_height along avg_n
	var target_orig = ground_point + avg_n * hover_height

	# Lerp full 3d position toward that target (this will kill manual jump)
	if _character.current_state.state_name == "grounded":
		var t = clamp(hover_lerp_speed * delta, 0.0, 1.0)
		var new_orig = current_orig.lerp(target_orig, t)
		var xform = character.global_transform
		xform.origin = new_orig
		character.global_transform = xform

	# Strip any velocity into the surface so don’t sink
	var inward = character.velocity.dot(avg_n)
	if inward < 0:
		character.velocity -= avg_n * inward
		

#var max_slope_degrees := 90.0  
#var max_slope_cos := cos(deg_to_rad(max_slope_degrees))

#func is_hover_contact() -> bool:
	#var threshold = hover_height + deadzone
	#for gap in get_corner_gaps():
		#if gap <= threshold:
			#return true
	#return false
	
# this function is very important as different states (like jumping and drifting)
# rely heavily on this check so it needs to be accurate to different situations
func is_grounded() -> bool:
	const NUM_OF_RAYS := 4
	var normals := get_corner_normals()
	return normals.size() == NUM_OF_RAYS
		
func clear_lateral_velocity(character: Character) -> void:
	var side = HelperFunctions.get_side_axis(character)
	var lat = character.velocity.dot(side)
	character.velocity -= side * lat
	
# probaly move these into my Helper function

func get_corner_distances() -> Array:
	var dists := []
	for r in raycasts:
		if not r.is_colliding(): continue
		var n = r.get_collision_normal()
		var offset = r.global_transform.origin - r.get_collision_point()
		dists.append(offset.dot(n))
	return dists
	
# Collects the collision normals from each corner raycast for surface alignment
func get_corner_normals() -> Array:
	var normals = []
	for r in self.raycasts:
		if r.is_colliding():
			normals.append(r.get_collision_normal())
	return normals

# Averages a list of surface-normal vectors into a single unit vector for tilting the board
func average_normals(normals: Array) -> Vector3:
	if normals.is_empty():
		return Vector3.UP
	var sum := Vector3.ZERO
	for n in normals:
		sum += n
	var avg := sum / normals.size()   # Vector3 / int
	return avg.normalized()

func get_average_surface_normal() -> Vector3:
	var normals = self.get_corner_normals()
	if normals.is_empty():
		return Vector3.UP
		
	var avg_normal = self.average_normals(normals)
	return avg_normal

func get_forward_direction_relative_to_surface(character: Character) -> Vector3:
	var n = self.get_y_relative_to_surface()
	var f = -character.global_transform.basis.z.normalized()
	return (f - n * f.dot(n)).normalized()

# rename to: get surface‑tangent velocity
func get_hvel_relative_to_surface(character: Character) -> Vector3:
	# Ensure normal points “up”
	var n = self.get_y_relative_to_surface()
	# v_tangent = v - (v·n) n
	var v = character.velocity
	return (v - n * v.dot(n))
	
func get_y_relative_to_surface():
	var n = self.get_average_surface_normal()
	if n.dot(Vector3.UP) < 0:
		n = -n
	return n
	
# Collects the vertical distance from each raycast origin to its collision point for hover spring calculations
func get_corner_gaps() -> Array:
	var gaps = []
	for r in self.raycasts:
		if r.is_colliding():
			gaps.append(r.global_transform.origin.y - r.get_collision_point().y)
	return gaps

# Computes the average of those gap distances to determine overall hover error
func average_gaps(gaps: Array) -> float:
	var total = 0.0
	for g in gaps:
		total += g
	return total / gaps.size()

func is_partially_grounded() -> bool:
	const AIRBORNE := 0
	const GROUNDED := 4
	var rays := []
	for r in raycasts:
		if not r.is_colliding(): 
			rays.append(r)
	if rays.size() != AIRBORNE or GROUNDED:
		return true
	return false
