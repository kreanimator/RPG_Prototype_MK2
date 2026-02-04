extends LegsAction

@export var animation : String = "Idle"

func setup_animator(previous_action : LegsAction, _input : InputPackage):
	if previous_action.anim_settings == anim_settings:
		legs_animator.play(animation, 0.15)
	else:
		legs_animator.play(animation, 0)
		legs_anim_settings.play(anim_settings, 0.15)
