extends CharacterBody3D
class_name Character

# since the script deals with raycasts we insance this to a 3D node to get state
@export var terrain_interactions_path: NodePath
@onready var _terrain_interactions: TerrainInteractions = get_node(terrain_interactions_path)
@export var visual_roll_path: NodePath
@onready var _visual_roll_controller: VisualRollController = get_node(visual_roll_path)

# state and inputs exposed
var current_state : State = null
var input_forward := false
var input_backward := false
var input_left := false
var input_right := false
var input_boost := false
var input_jump_just_pressed := false
var input_jump_held := false
var input_jump_released := false



# used across some states. I could inject them but this is easier for now
var base_jump_yaw = 0.0
var top_speed := 50.0  # used in acceleration; steering; hclamp; tend to zero
var drift_dir = 0
var left_drift = false
var right_drift = false

func _ready():
	current_state = GroundState.new()
	# inject our terrain_interaction node/script at start 
	current_state._terrain_interactions = _terrain_interactions
	current_state._visual_roll_controller = _visual_roll_controller
	# if ever have an `enter()` callback (for groundstate), call it here

func _physics_process(delta: float) -> void:
	_handle_inputs()
	var _events = _handle_events()
	for trigger in _events:
		var next_state = current_state.on_trigger(self, trigger, delta)
		if next_state:
			load_and_configure_next_state(next_state, delta)
			break    # only one trigger→state change per frame
	
	current_state.update(self, delta)

		
func load_and_configure_next_state(next_state: State, delta: float):
		current_state.exit(self, delta)
		current_state = next_state
		# inject every state
		current_state._terrain_interactions = _terrain_interactions
		current_state._visual_roll_controller = _visual_roll_controller
		current_state.enter(self, delta)

func _handle_inputs():
	input_forward  = Input.is_action_pressed("forward")
	input_backward = Input.is_action_pressed("back")
	input_left = Input.is_action_pressed("left")
	input_right = Input.is_action_pressed("right")
	input_jump_just_pressed = Input.is_action_just_pressed("jump_drift")
	input_jump_held  = Input.is_action_pressed("jump_drift")
	input_jump_released = Input.is_action_just_released("jump_drift")

var _was_grounded := false
var _was_partially_grounded := false

func _handle_events() -> Array:
	var _events := []
	# input event transitions
	if input_forward:
		_events.append(Events.Trigger.FORWARD)
	if input_backward:
		_events.append(Events.Trigger.BACKWARD)
	if input_left:
		_events.append(Events.Trigger.LEFT)
	if input_right:
		_events.append(Events.Trigger.RIGHT)
	if input_jump_just_pressed:
		_events.append(Events.Trigger.JUMP_PRESS)
	if input_jump_held:
		_events.append(Events.Trigger.JUMP_HELD)
	if input_jump_released:
		_events.append(Events.Trigger.JUMP_RELEASE)
	
	# environment‑based transitions
	var _grounded := _terrain_interactions.is_grounded()
	if _grounded and not _was_grounded:
		_events.append(Events.Trigger.LANDED)
	if not _grounded and _was_grounded:
		_events.append(Events.Trigger.AIRBORNE)
	var _partially_grounded := _terrain_interactions.is_partially_grounded()
	if _partially_grounded and not _was_partially_grounded:
		_events.append(Events.Trigger.CORNER_FALL)

	# stash for next frame
	_was_grounded = _grounded
	_was_partially_grounded = _partially_grounded
	#print(_events)
	#print(current_state.state_name)
	return _events

# UTILS
## airtime tracking
#var _in_air := false
#var current_air_time := 0.0
#var last_air_time := 0.0
#
#func _update_air_time(delta):
	#var grounded = terrain_interactions.is_hover_contact()()
	#if not grounded:
		## we’re airborne: accumulate
		#current_air_time += delta
		#_in_air = true
	#elif _in_air:
		## we just landed: record and reset
		#last_air_time = current_air_time
		#current_air_time = 0.0
		#_in_air = false
