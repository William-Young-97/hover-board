extends CharacterBody3D
class_name Character

# since the script deals with raycasts we insance this to a 3D node to get state
@export var terrain_interactions_path: NodePath
@onready var _terrain_interactions: TerrainInteractions = get_node(terrain_interactions_path)

# state and inputs exposed
var current_state : State = null
var input_forward    := false
var input_backward   := false
var input_left := false
var input_right := false
var input_boost      := false
var input_jump       := false
var input_drift_held     := false
var input_drift_release := false
var input_turn := 0.0
var _triggers := []

# used across some states. I could inject them but this is easier for now
var base_jump_yaw = 0.0
var top_speed := 50.0  # used in acceleration; steering; hclamp; tend to zero

var drift_dir = 0
var left_drift = false
var right_drift = false

func _ready():
	current_state = GroundState.new()
	# inject our terrain_interaction node/script at start 
	current_state.terrain_interactions = _terrain_interactions
	# if ever have an `enter()` callback (for groundstate), call it here

func _physics_process(delta: float) -> void:
	_triggers = _handle_inputs()

	for trigger in _triggers:
		var next_state = current_state.on_trigger(self, trigger)
		if next_state:
			load_and_configure_next_state(next_state, delta)
			break    # only one trigger→state change per frame

	var next_state = current_state.update(self, delta)
	if next_state:
		load_and_configure_next_state(next_state, delta)
		
func load_and_configure_next_state(next_state: State, delta: float):
		current_state.exit(self, delta)
		current_state = next_state
		# inject every state
		current_state.terrain_interactions = _terrain_interactions
		current_state.enter(self, delta)

func _handle_inputs() -> Array:
	var _out := []
	input_forward  = Input.is_action_pressed("forward")
	input_backward = Input.is_action_pressed("back")
	input_left = Input.is_action_pressed("left")
	input_right = Input.is_action_pressed("right")
	input_jump = Input.is_action_just_pressed("jump_drift")
	input_drift_held  = Input.is_action_pressed("jump_drift")
	input_drift_release = Input.is_action_just_released("jump_drift")
	
	# gives steering input
	# works as we start in grounded and other states exit to grounded without triggers
	# reset to 0 each frame
	input_turn = 0.0
	if input_left :
		input_turn += 1.0
	if input_right:
		input_turn -= 1.0

	if input_jump:
		_out.append(Triggers.Actions.JUMP)
	
	# assuming jump is held AND state = jump (on trig only matches for jump state no other)
	# and we get a dir input we can start drift
	# like most threshold should add visual and audio to show failure
	# this can be done by emiting a signal here
	var drift_entry_threshhold = 20
	if input_drift_held and (input_left or input_right) \
	and HelperFunctions.get_mph(self) > drift_entry_threshhold:
			_out.append(Triggers.Actions.START_DRIFT)
	if input_drift_release:
		_out.append(Triggers.Actions.END_DRIFT)
	return _out

# UTILS
## airtime tracking
#var _in_air := false
#var current_air_time := 0.0
#var last_air_time := 0.0
#
#func _update_air_time(delta):
	#var grounded = is_grounded()
	#if not grounded:
		## we’re airborne: accumulate
		#current_air_time += delta
		#_in_air = true
	#elif _in_air:
		## we just landed: record and reset
		#last_air_time = current_air_time
		#current_air_time = 0.0
		#_in_air = false
