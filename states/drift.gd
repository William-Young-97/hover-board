extends State
class_name DriftState

# TODO
# guard against players dobule drifting in the same direction
# can also penalise it in my boost sytstem as it counts as not following a boost through

var state_name = "drifting"
var _inward_drift_timer = 0

var _dh: DriftHelper
	
func enter(character: Character, delta) -> void:
	_dh = DriftHelper.new(ti, vrc, lm, rm)
	vrc.board_roll_amount = 0.8
	print("Entering Drift")
	
	
func exit(character: Character, delta) -> void:
	character.call_deferred("emit_signal", "exited_drift")
	

func update(character: Character, delta) -> void:
	vrc.board_roll_amount = 0.8
	
	ti.enforce_max_speed(character)
	ti.apply_leveling_slerp(character, ti.grays, delta)
	ti.enforce_hover_floor(character,  ti.grays, delta)
	ti.apply_gravity(delta)
	character.move_and_slide()
	
	_dh._exit_at_20_mph(character)
	_dh._apply_drift(character, delta)
	
func on_trigger(character: Character, trigger: int, delta: float) -> State:
	match trigger:
		Events.Trigger.FORWARD:
			_dh._accelerate_drift(character, delta)
		Events.Trigger.BACKWARD:
			_dh._decelerate_drift(character, delta)
		Events.Trigger.JUMP_RELEASE:
			return GroundState.new()
		Events.Trigger.AIRBORNE:
			#return AirborneState.new()
			return AirborneDriftState.new()
	return null
