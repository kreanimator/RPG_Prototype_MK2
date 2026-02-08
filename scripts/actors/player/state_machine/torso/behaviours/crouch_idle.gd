extends TorsoBehaviour

var animation: String = "Crouch_Idle"

func transition_logic(input : InputPackage) -> String:
	map_with_dictionary(input)
	return best_input_that_can_be_paid(input)

func on_enter_behaviour(_input : InputPackage):
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)
		
func setup_legs_animator(previous_action : LegsAction, _input : InputPackage):
	if previous_action.anim_settings == "simple":
		legs.simple_animator.play(animation, 0.15)
	else:
		legs.simple_animator.play(animation, 0)
		legs.legs_anim_settings.play(animation, 0.15)
