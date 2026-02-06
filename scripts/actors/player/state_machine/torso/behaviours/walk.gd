extends TorsoBehaviour

var animation: String = "Walk"


func transition_logic(input : InputPackage) -> String:
	map_with_dictionary(input)
		# stop -> switch to idle (input can also drive this; this is a safe fallback)
	if player.nav_agent.is_navigation_finished():
		return "idle"
	return best_input_that_can_be_paid(input)

func on_enter_behaviour(_input : InputPackage):
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)
