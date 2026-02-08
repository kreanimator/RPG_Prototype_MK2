extends TorsoAction

func setup_animator(_input : InputPackage):
	if torso_anim_settings.current_animation == "simple": # ie both are simple of AnimatorModifier type
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)
	
	if parent_behaviour.legs.legs_anim_settings.current_animation == "simple": # ie both are simple of AnimatorModifier type
		parent_behaviour.legs.simple_animator.play(animation, 0.15)
	else:
		parent_behaviour.legs.simple_animator.play(animation, 0)
		parent_behaviour.legs.legs_anim_settings.play("simple", 0.15)
	
