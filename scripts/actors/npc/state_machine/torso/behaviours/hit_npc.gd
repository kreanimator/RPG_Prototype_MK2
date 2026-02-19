extends TorsoBehaviourNPC

#var animation: String = "anim_pack_2/LiftAir_Hit_R"
var animation: String = "Hit_Head"

func transition_logic(input : AIInputPackage) -> String:
	map_with_dictionary(input)
	
	if animation_duration > 0.0 and behaves_longer_than(animation_duration):
		return best_input_that_can_be_paid(input)
	
	return "okay"

func on_enter_behaviour(_input : AIInputPackage):
	print("[HitNPC] Entering hit behaviour for actor: %s" % actor.actor_name)
	if animations_source and animations_source.has_animation(animation):
		animation_duration = animations_source.get_animation(animation).length
		
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)
