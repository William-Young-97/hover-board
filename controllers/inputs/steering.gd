extends Node3D

@export var character_path: NodePath
@onready var _character: Character = get_node(character_path)

@export var ls_path: NodePath
@onready var ls: = get_node(ls_path)

@export var rs_path: NodePath
@onready var rs: = get_node(rs_path)

var probes: Array[RayCast3D] = []

func _ready():
	pass

func _physics_process(delta):
	var left_points = get_left_edge_points(ls)
	var right_points = get_right_edge_points(rs)
	
	var left_edge = get_outermost_point(left_points, true)
	var right_edge = get_outermost_point(right_points, false)
	var local_left  = global_transform.affine_inverse() * left_edge
	var local_right = global_transform.affine_inverse() * right_edge
	
	var centerline = (local_left + local_right) * 0.5
	var world_midpoint = global_transform * centerline
	print("left edge: ", left_edge)
	print("right edge: ", right_edge)
	print("Centerline:", world_midpoint)
	
func get_left_edge_points(left_cast: ShapeCast3D) -> Array:
	var edge_points: Array = []
	
	for i in range(left_cast.get_collision_count()):
		var hit_pos: Vector3 = left_cast.get_collision_point(i)
		
		# Convert to vehicle local space
		var local_hit = global_transform.affine_inverse() * hit_pos
		
		# Keep only points on left side
		#if local_hit.x < 0.0:
		edge_points.append(hit_pos)
	
	return edge_points

func get_right_edge_points(right_cast: ShapeCast3D) -> Array:
	var edge_points: Array = []
	
	for i in range(right_cast.get_collision_count()):
		var hit_pos: Vector3 = right_cast.get_collision_point(i)
		
		# Convert to vehicle local space
		
		var local_hit = global_transform.affine_inverse() * hit_pos
		
		# Keep only points on left side
		#if local_hit.x > 0.0:
		edge_points.append(hit_pos)
	
	return edge_points

func get_virtual_centerline(left_points: Array, right_points: Array) -> Vector3:
	# If either side has no points, we can't calculate a midpoint
	if left_points.is_empty() or right_points.is_empty():
		return Vector3.ZERO

	# Average all points on each side
	var left_avg := Vector3.ZERO
	for p in left_points:
		left_avg += p
	left_avg /= float(left_points.size())

	var right_avg := Vector3.ZERO
	for p in right_points:
		right_avg += p
	right_avg /= float(right_points.size())

	# Midpoint between left and right averages
	return (left_avg + right_avg) * 0.5
	
func get_outermost_point(points: Array, is_left: bool) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var best_point = points[0]
	for p in points:
		if is_left:
			if p.x < best_point.x:
				best_point = p
		else:
			if p.x > best_point.x:
				best_point = p
	return best_point
