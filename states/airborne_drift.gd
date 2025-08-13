extends State
class_name AirborneDriftState

var state_name = "airborne_drift"
var _inward_drift_timer = 0

var _dh: DriftHelper

func enter(character: Character, delta) -> void:
	_dh = DriftHelper.new(ti, vrc)
	vrc.board_roll_amount = 0.8
	print("Entering Airborne Drift")
	
func exit(character: Character, delta: float) -> void:
	pass

func update(character: Character, delta: float) -> void:
	character.move_and_slide()
	ti.apply_leveling_slerp(character, ti.grays, delta)
	ti.apply_gravity(delta, 3)
	_dh._apply_drift(character, delta)
	
func on_trigger(character: Character, trigger: int, delta: float) -> State:
	match trigger:
		Events.Trigger.FORWARD:
			_dh._accelerate_drift(character, delta)
		Events.Trigger.BACKWARD:
			_dh._decelerate_drift(character, delta)
		Events.Trigger.JUMP_RELEASE:
			if ti.should_land(ti.grays) == false:
				return AirborneState.new()
			return GroundState.new()
		Events.Trigger.LANDED:
			return DriftState.new()
	return null
