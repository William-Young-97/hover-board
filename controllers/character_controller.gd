extends CharacterBody3D
class_name Character

# since the script deals with raycasts we insance this to a 3D node to get state

@export var terrain_interactions_path: NodePath
@onready var _ti: TerrainInteractions = get_node(terrain_interactions_path)
@export var visual_roll_path: NodePath
@onready var _vrc: VisualRollController = get_node(visual_roll_path)
#@export var drift_helper_path: NodePath
#@onready var _dh: DriftHelper = get_node(drift_helper_path)


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
var jumped = false
var air_base_entry_yaw = 0.0
var top_speed := 50.0  # used in acceleration; steering; hclamp; tend to zero

var drift_dir = 0
var left_drift = false
var right_drift = false

	
func _ready():
	# inject *this* character into the roll controller
	_vrc.character = self
	current_state = GroundState.new()
	current_state.ti = _ti
	current_state.vrc = _vrc
	#current_state.dh = _dh
	
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
		current_state.ti = _ti
		current_state.vrc = _vrc
		#DDDcurrent_state.dh = _dh
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
var _was_airborne := false

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
	if _ti.should_land(_ti.grays):
		_events.append(Events.Trigger.LANDED)
	
	if _ti.should_leave_ground(_ti.grays):
		_events.append(Events.Trigger.AIRBORNE)
	return _events
