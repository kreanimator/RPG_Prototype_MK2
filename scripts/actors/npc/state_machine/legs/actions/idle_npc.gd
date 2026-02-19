extends LegsActionNPC

@export var animation : String = "anim_pack_2/Zombie_Idle"

func setup_animator(previous_action : LegsActionNPC, _input : AIInputPackage):
	if previous_action.anim_settings == anim_settings:
		legs_animator.play(animation, 0.15)
	else:
		legs_animator.play(animation, 0)
		legs_anim_settings.play(anim_settings, 0.15)
