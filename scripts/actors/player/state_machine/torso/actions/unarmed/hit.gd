extends TorsoAction

var hit_action_mapper: Dictionary = {
	"punch": ["Punch_Cross", "Punch_Jab"],
	"kick": ["Kick"]
	#"punch": ["anim_pack_2/Melee_Hook", "anim_pack_2/Melee_Uppercut"],
	#"kick": ["Kick", "anim_pack_2/Melee_Knee"]
}

func setup_animator(_input : InputPackage):
	animation = get_current_animation()
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

func get_current_animation() -> String:
	var stats := player.player_model.stats_manager as StatsManager
	var key := stats.get_unarmed_action_key()
	var options: Array = hit_action_mapper.get(key)

	if options.size() == 1:
		return options[0]

	return options[randi() % options.size()]
