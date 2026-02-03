extends TorsoBehaviour

func transition_logic(input : InputPackage) -> String:
	map_with_dictionary(input)
	return best_input_that_can_be_paid(input)

func on_enter_behaviour(_input : InputPackage):
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play("walk_n", 0.15)
	else:
		simple_torso.play("walk_n", 0)
		torso_anim_settings.play("simple", 0.15)