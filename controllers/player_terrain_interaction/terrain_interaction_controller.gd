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

func _physics_process(delta: float) -> void:
	match _character.current_state.state_name:
		"grounded", "manual_jump", "jump_rotation", "drifting":
			self.apply_character_gravity(_character, delta)
			self.apply_hover(_character, raycasts, delta)
			_character.move_and_slide()
		
		"grounded":
			HelperFunctions.horizontal_clamp(_character)
			HelperFunctions.clear_lateral_velocity(_character)
		
# gravity
func apply_character_gravity(character: Character, delta: float) -> void:
	if not self.is_grounded(character):
		character.velocity.y -= gravity * delta
	else:
		character.velocity.y = max(character.velocity.y, 0)
# hover set to same height as raycast length
var hover_height := 0.25
var deadzone := 0.05
var spring_k := 50
var damping := 2 * sqrt(spring_k)

# "pushes" board up when ray casts collide inside obejct
func apply_hover(character: Character, raycasts: Array, delta: float):
	var gaps = self.get_corner_gaps()
	if gaps.is_empty(): return
	var avg_gap = self.average_gaps(gaps)
	var error = avg_gap - hover_height
	if abs(error) > deadzone:
		var force = -spring_k * error
		var damp_force = -damping * character.velocity.y
		character.velocity.y += (force + damp_force) * delta
		
func is_grounded(character: Character) -> bool:
	var gaps = self.get_corner_gaps()
	# if no ray is hitting, we’re clearly airborne
	if gaps.is_empty():
		return false

	# if any corner is within hover_height + deadzone, we consider ourselves grounded
	var threshold = self.hover_height + self.deadzone
	for gap in gaps:
		if gap <= threshold:
			return true
	return false

func average_gaps(gaps: Array) -> float:
	var total = 0.0
	for g in gaps:
		total += g
	return total / gaps.size()

func get_corner_gaps() -> Array:
	var gaps = []
	for r in self.raycasts:
		if r.is_colliding():
			gaps.append(r.global_transform.origin.y - r.get_collision_point().y)
	return gaps
