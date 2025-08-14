extends InputProvider
class_name HumanInput

func is_forward():       return Input.is_action_pressed("forward")
func is_backward():      return Input.is_action_pressed("back")
func is_left():          return Input.is_action_pressed("left")
func is_right():         return Input.is_action_pressed("right")
func is_jump_pressed():  return Input.is_action_just_pressed("jump_drift")
func is_jump_held():     return Input.is_action_pressed("jump_drift")
func is_jump_released(): return Input.is_action_just_released("jump_drift")
func is_pause() -> bool: return Input.is_action_pressed("pause")
