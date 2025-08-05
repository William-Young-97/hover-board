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

const HOVER_LOWER_BAND  = 0.5
const HOVER_UPPER_BAND    = 0.8
#const MAX_SLOPE_ANGLE = 50
#const COS_MAX_SLOPE  = cos(deg_to_rad(MAX_SLOPE_ANGLE))

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

# used by Grounded → Airborne
func should_leave_ground(rays: Array[RayCast3D]) -> bool:
	for ray in rays:
		if not ray.is_colliding():
			return true
		var gap = ray.global_transform.origin.y - ray.get_collision_point().y
		if gap > HOVER_UPPER_BAND :
			return true
	return false

func enforce_hover_floor(character: Character, rays: Array[RayCast3D], delta: float) -> void:
	# 1) compute the average slope normal once
	var n = get_ground_normal(rays)
	if n.dot(Vector3.UP) < 0:
		n = -n
	# spring stiffness (tweak between ~4–12)
	var stiffness := 12.0

	for ray in rays:
		if not ray.is_colliding():
			continue

		# 2) measure penetration distance ALONG that normal
		var origin = ray.global_transform.origin
		var hit    = ray.get_collision_point()
		var gap    = (origin - hit).dot(n)

		# 3) if you’re below the hover‑floor, snap up & add velocity
		if gap < HOVER_LOWER_BAND:
			var correction = HOVER_LOWER_BAND - gap
			# positional correction (keeps you from clipping)
			character.translate(n * correction)

			# **inject vertical speed** so you bounce back up
			# impulse = correction * stiffness  (units: speed)
			# you can multiply by delta if you prefer an 'acceleration' style spring
			
			#character.velocity += n * (correction * stiffness)

			return
		# 4) if you’re above it, pull down (same deal)
		elif gap > HOVER_LOWER_BAND:
			var down = gap - HOVER_LOWER_BAND
			character.translate(-n * down)

			# optional: add a small downward impulse so you settle faster
			#character.velocity -= n * (down * stiffness * 0.5)

			return

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
		# skip walls
		#if n.dot(Vector3.UP) < COS_MAX_SLOPE:
			#continue

		sum += n
		count += 1
	if count == 0:
		return Vector3.UP
	return (sum / count).normalized()

# lower for smoother slerp
const ALIGN_SPEED_GROUND = 6.0

func check_air_or_ground_ray(rays: Array[RayCast3D]) -> bool:
	var use_hover_band = true
	if rays.size() > 0 and rays[0].target_position.length() > HOVER_UPPER_BAND:
		use_hover_band = false
	return use_hover_band

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

func slide_on_slopes(character: Character, raycast_type: Array[RayCast3D]):
	var normal = get_ground_normal(raycast_type)
	character.velocity = character.velocity.slide(normal)

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
