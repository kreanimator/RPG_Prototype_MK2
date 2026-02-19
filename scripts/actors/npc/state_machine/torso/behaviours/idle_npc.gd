extends TorsoBehaviourNPC

var animation: String = "anim_pack_2/Zombie_Idle"

func transition_logic(input : AIInputPackage) -> String:
	map_with_dictionary(input)
	return best_input_that_can_be_paid(input)

func on_enter_behaviour(_input : AIInputPackage):
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)
