extends InputProvider
class_name AIInput

@onready var respawn_manager: RespawnManager

@export var character: Character
@export var waypoints: Array[Node]
@export var arrive_radius: float = 5
@export var target_speed: float = 110.0
@export var steer_deadzone: float = 0.03
@export var lookahead_distance: float = 1.0
@export var path_half_width: float = 2

var _i := 0
var _fwd := false
var _back := false
var _left := false
var _right := false
var _steer_value := 0.0
var _prev_steer_value := 0.0


func _ready() -> void:
	if waypoints.is_empty():
		waypoints = get_tree().get_nodes_in_group("way_points")
	respawn_manager = get_tree().get_first_node_in_group("respawn_manager")
	respawn_manager.connect("respawned", set_waypoint)

# pass param because respawn (which emits) has this arg
func set_waypoint(_body: Character):
	_i = find_next_waypoint_index(character.global_transform.origin, waypoints)
	
func find_next_waypoint_index(player_pos: Vector3, waypoints: Array[Node]) -> int:
	print("here")
	var best_seg_index := -1
	var best_seg_dist := INF

	for i in range(waypoints.size()):
		var a = waypoints[i].global_transform.origin
		var b = waypoints[(i + 1) % waypoints.size()].global_transform.origin

		var ab = b - a
		var ap = player_pos - a

		# Project and clamp to find closest point
		var t = clamp(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
		var closest_point = a + ab * t
		var dist := player_pos.distance_squared_to(closest_point)

		if dist < best_seg_dist:
			best_seg_dist = dist
			best_seg_index = i

	# Direction check to avoid picking a behind waypoint
	var start_wp = waypoints[best_seg_index].global_transform.origin
	var end_wp = waypoints[(best_seg_index + 1) % waypoints.size()].global_transform.origin
	var seg_dir = (end_wp - start_wp).normalized()
	var to_player = (player_pos - start_wp).normalized()

	if seg_dir.dot(to_player) < 0.0:
		# ai is behind → pick start waypoint
		return best_seg_index
	else:
		# ai is ahead → pick end waypoint
		return (best_seg_index + 1) % waypoints.size()


	
func _physics_process(_dt: float) -> void:
	var pos := character.global_transform.origin

	_update_waypoint_index(pos)
	var wp_a = waypoints[_i].global_transform.origin
	var wp_b = waypoints[(_i + 1) % waypoints.size()].global_transform.origin

	var seg = wp_b - wp_a
	var seg_dir = seg.normalized()
	var to_pos = pos - wp_a
	var proj_len = clamp(to_pos.dot(seg_dir), 0.0, seg.length())
	var proj_point = wp_a + seg_dir * proj_len
	var lateral_offset = (pos - proj_point).dot(character.global_transform.basis.x)  # signed left/right offset

	var goal = _get_target_point(pos)
	var local_goal = character.global_transform.affine_inverse() * goal
	var steer_angle = atan2(local_goal.x, max(0.001, local_goal.z))


	if abs(lateral_offset) <= path_half_width:
		_left = false
		_right = false
	else:
		_left  = steer_angle < -steer_deadzone
		_right = steer_angle >  steer_deadzone

	var speed := character.velocity.length()
	if _edge_ahead() and speed > 50:
		_fwd = false
		_back = true  
	else:
		_fwd  = speed < (target_speed)
		_back = speed > (target_speed)

func _update_waypoint_index(pos: Vector3) -> void:
	var arrive_pos = waypoints[_i].global_transform.origin
	
	if pos.distance_to(arrive_pos) <= arrive_radius:
		_i = (_i + 1) % waypoints.size()
		return
	
	var next_i = (_i + 1) % waypoints.size()
	var next_pos = waypoints[next_i].global_transform.origin
	if pos.distance_to(next_pos) < pos.distance_to(arrive_pos):
		_i = next_i
		

func _get_target_point(pos: Vector3) -> Vector3:
	var idx := _i
	var dist_accum := 0.0
	while dist_accum < lookahead_distance:
		var next_idx := (idx + 1) % waypoints.size()
		var seg_len = waypoints[idx].global_transform.origin.distance_to(
			waypoints[next_idx].global_transform.origin
		)
		dist_accum += seg_len
		idx = next_idx
	return waypoints[idx].global_transform.origin
	
@export var ray_forward_offset: float = 22
@export var ray_length: float = 30.0
@export var ray_height_offset: float = 8
@export var cone_angle_deg: float = 30.0
@export var cone_rays: int = 3
@export var debug_draw_rays: bool = true
@export var ray_side_spacing: float = 5.5

func _edge_ahead() -> bool:
	var forward_dir = -character.global_transform.basis.z.normalized()
	
	var start_pos = character.global_transform.origin \
		+ Vector3.UP * ray_height_offset \
		+ forward_dir * ray_forward_offset

	var half_angle = deg_to_rad(cone_angle_deg / 2.0)
	var edge_detected = false

	for i in range(cone_rays):
		var t = lerp(-1.0, 1.0, float(i) / float(cone_rays - 1))

		var lateral_offset = character.global_transform.basis.x * (t * ray_side_spacing)

		var angle = t * half_angle
		var dir = (forward_dir.rotated(Vector3.UP, angle)).normalized()

		var from = start_pos + lateral_offset
		var to = from + dir * 2.0 + Vector3.DOWN * ray_length

		var hit = character.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, to)
		)

		if hit.is_empty():
			edge_detected = true

		if debug_draw_rays:
			var end_pos: Vector3
			var color: Color
			if hit.is_empty():
				end_pos = to
				color = Color.RED
			else:
				end_pos = hit.position
				color = Color.GREEN

			DebugDraw3D.draw_line(from, end_pos, color, 0.05)

	return edge_detected

func is_forward() -> bool: return _fwd
func is_backward() -> bool: return _back
func is_left() -> bool: return _left
func is_right() -> bool: return _right
func is_jump_pressed() -> bool: return false
func is_jump_held() -> bool: return false
func is_jump_released() -> bool: return false
func is_pause() -> bool: return false
