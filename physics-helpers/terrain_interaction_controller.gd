extends Node
class_name TerrainInteractions

# TODO
# Rename this to handler
# adjust get ground normals to deal with air rays when in that state
# create apply gravity

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var character_path: NodePath
@onready var _character: = get_node(character_path)


@export var gfl_path: NodePath
@export var gfr_path: NodePath
@export var gbl_path: NodePath
@export var gbr_path: NodePath

@onready var gfl: RayCast3D = get_node(gfl_path)
@onready var gfr: RayCast3D = get_node(gfr_path)
@onready var gbl: RayCast3D = get_node(gbl_path)
@onready var gbr: RayCast3D = get_node(gbr_path)
@onready var grays = [gfl, gfr, gbl, gbr] as Array[RayCast3D]

@export var afl_path: NodePath
@export var afr_path: NodePath
@export var abl_path: NodePath
@export var abr_path: NodePath

# ensure that these always point down in world space
@onready var afl: RayCast3D = get_node(afl_path)
@onready var afr: RayCast3D = get_node(afr_path)
@onready var abl: RayCast3D = get_node(abl_path)
@onready var abr: RayCast3D = get_node(abr_path)

@onready var arays = [afl, afr, abl, abr] as Array[RayCast3D]

const HOVER_LOWER_BAND = 0.5
const HOVER_UPPER_BAND = 1.5
const HOVER_HEIGHT = HOVER_LOWER_BAND + 0.3


func enforce_max_speed(character: Character) -> void:
	var v = character.velocity
	var mag = v.length()
	if mag > character.top_speed:
		character.velocity = v.normalized() * character.top_speed
		

func apply_gravity(delta: float, modifier := 1.0):
	_character.velocity.y -= self.gravity * delta * modifier

# used by Airborne → Grounded
func should_land(rays: Array[RayCast3D]) -> bool:
	for ray in rays:
		if not ray.is_colliding():
			continue
		var gap = ray.global_transform.origin.y - ray.get_collision_point().y
		var n   = ray.get_collision_normal()
		if gap <= HOVER_LOWER_BAND: #and n.dot(Vector3.UP) >= COS_MAX_SLOPE:
			return true
	return false

func _apply_landing_damper(character: Character) -> void:
	const LANDING_NORMAL_DAMP := 0.05

	var n = get_ground_normal(grays)
	if n.dot(Vector3.UP) < 0:
		n = -n
	n = n.normalized()

	var v = character.velocity
	var normal_spd = v.dot(n)
	var planar_v = v - n * normal_spd   

	normal_spd *= LANDING_NORMAL_DAMP

	character.velocity = planar_v + n * normal_spd

# used by Grounded → Airborne
func should_leave_ground(rays: Array[RayCast3D]) -> bool:
	for ray in rays:
		if not ray.is_colliding():
			return true
		var gap = ray.global_transform.origin.y - ray.get_collision_point().y
		if gap > HOVER_UPPER_BAND :
			return true
	return false
	
const DEAD := 0.2
const MAX_LIFT := 2.0

const MAX_PULL = 8.0


func enforce_hover_floor(character: CharacterBody3D, rays: Array[RayCast3D], delta: float) -> void:

	var total_gap = 0.0
	var total_n   = Vector3.ZERO
	var count     = 0
	for ray in rays:
		if not ray.is_colliding(): continue
		var this_n = get_ground_normal(rays)
		if this_n.dot(Vector3.UP) < 0:
			this_n = -this_n
		total_n   += this_n
		total_gap += (ray.global_transform.origin - ray.get_collision_point()).dot(this_n)
		count += 1
	if count == 0: return
	var n     = (total_n / count).normalized()
	var gap   = total_gap / count
	var error = gap - HOVER_HEIGHT

	var old_v      = character.velocity
	var normal_spd = old_v.dot(n)
	var planar_v   = old_v - n * normal_spd
	var planar_spd = planar_v.length()
	if planar_spd < 0.001:
		planar_v = (Vector3.DOWN - n * Vector3.DOWN.dot(n)).normalized()
		planar_spd = 0.0

	if abs(error) < DEAD:
		if normal_spd < 0:
			normal_spd = 0
		character.velocity = planar_v.normalized() * planar_spd + n * normal_spd
		return

	if error < 0:

		var needed_v = error / delta 
		needed_v = clamp(needed_v, -MAX_LIFT, 0.0)
		normal_spd -= needed_v
	elif error > 0:
		var needed_v = error / delta
		needed_v = clamp(needed_v, 0.0, (MAX_PULL))
		normal_spd -= needed_v

	character.velocity = planar_v.normalized() * planar_spd + n * normal_spd

func get_ground_normal(rays: Array[RayCast3D], use_hover_band := true) -> Vector3:
	var sum = Vector3.ZERO
	var count = 0
	for ray in rays:
		if not ray.is_colliding():
			continue
		
		# if we are using ground rays calculate the offset for our collision point
		if use_hover_band:
			var origin = ray.global_transform.origin.y 
			var col_point = ray.get_collision_point().y
			var gap = origin - col_point
			
			if gap > HOVER_UPPER_BAND:
				continue
		# otherwise we are using air rays and we lock them to always point down.
		# seems ok for now even thoguh the rays look a bit spazzy
		else:
			var origin = ray.global_transform.origin
			var down_point = origin + Vector3.DOWN * ray.target_position.length()
			ray.target_position = ray.to_local(down_point)
			ray.force_raycast_update()
			
		var n = ray.get_collision_normal()
		sum += n
		count += 1
	if count == 0:
		return Vector3.UP
	return (sum / count).normalized()

func check_air_or_ground_ray(rays: Array[RayCast3D]) -> bool:
	var use_hover_band = true
	if rays.size() > 0 and rays[0].target_position.length() > HOVER_UPPER_BAND:
		use_hover_band = false
	return use_hover_band


const ALIGN_SPEED_GROUND = 6.0

func apply_leveling_slerp(character: Character, rays: Array[RayCast3D], delta: float) -> void:
	var target_up  = get_ground_normal(rays, check_air_or_ground_ray(rays))
	var current_up = character.global_transform.basis.y.normalized()

	# compute current & target orientations as quaternions
	var current_q = Quaternion(character.global_transform.basis)
	
	# “error” quaternion that rotates current_up → target_up
	var axis      = current_up.cross(target_up).normalized()
	var angle     = acos(clamp(current_up.dot(target_up), -1,1))
	var error_q   = Quaternion(axis, angle)
	var target_q  = error_q * current_q

	# slerp toward it by a fraction each frame
	var t = clamp(ALIGN_SPEED_GROUND * delta, 0.0, 1.0)
	var new_q = current_q.slerp(target_q, t)

	character.global_transform.basis = Basis(new_q).orthonormalized()



func get_forward_direction_relative_to_surface(character: Character, raycast_type: Array[RayCast3D]) -> Vector3:
	# World‑space “up” of the slope
	var n = get_ground_normal(raycast_type)

	#  Board’s nose in world space
	var f = (-character.global_transform.basis.z).normalized()
	
	# Project f onto the plane defined by n:
	#    f_plane = f – (f·n) n
	var f_plane = (f - n * f.dot(n)).normalized()
	return f_plane

func get_hvel_relative_to_surface(character: Character, raycast_type: Array[RayCast3D]) -> Vector3:
	var n = get_ground_normal(raycast_type)
	var v = character.velocity
	# project v onto the slope plane
	return (v - n * v.dot(n))

func kill_lateral_velocity(character: Character, delta: float, bleed_time = 0.0, ):
	# 1) Get slope normal (always pointing up)
	var n = self.get_ground_normal(grays)
	if n.dot(Vector3.UP) < 0:
		n = -n

	# 2) Split your 3D velocity into planar + normal parts
	var old_v       = character.velocity
	var normal_spd  = old_v.dot(n)
	var planar_v    = old_v - n * normal_spd
	var planar_spd  = planar_v.length()
	if planar_spd < 0.01:
		return

	# 3) Build your true planar axes:
	#    side_axis_plane = board's local X, re‑projected into the slope plane
	var raw_side     = HelperFunctions.get_side_axis(character)
	var side_axis_plane = (raw_side - n * raw_side.dot(n)).normalized()

	# 4) Current travel‐direction
	var planar_dir   = planar_v / planar_spd

	# 5) Target direction = remove *all* side component from planar_dir
	#    by projecting planar_dir onto the plane orthogonal to side_axis_plane
	#    i.e. slide out the side_axis_plane component, then normalize.
	var tgt_dir = (planar_dir - side_axis_plane * planar_dir.dot(side_axis_plane)).normalized()

	# 6) Blend a little toward that side‑free target
	#    bleed_time = seconds to *fully* lose your side‑speed
	var t = clamp(delta / bleed_time, 0.0, 1.0)
	var new_dir = planar_dir.lerp(tgt_dir, t).normalized()

	# 7) Reassemble *exactly* the same planar speed + original normal speed
	character.velocity = new_dir * planar_spd + n * normal_spd
