extends TorsoAction

# Aim action for ranged weapons
# Switches/blends from idle to aim pose

func setup_animator(_input : InputPackage):
	# Play aim animation (blend from idle to aim)
	if animation.is_empty():
		animation = "Aim_Idle"  # Default aim animation name
	
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)  # Blend in
	else:
		simple_torso.play(animation, 0.0)
		torso_anim_settings.play("simple", 0.15)
	
	# Legs can stay in idle or play matching animation
	if parent_behaviour.legs.legs_anim_settings.current_animation == "simple":
		parent_behaviour.legs.simple_animator.play(animation, 0.15)
	else:
		parent_behaviour.legs.simple_animator.play(animation, 0.0)
		parent_behaviour.legs.legs_anim_settings.play("simple", 0.15)
	
	# Enable precise aim mode for ranged weapons
	var weapon = player.player_model.active_weapon
	if weapon is RangedWeapon:
		if player.player_model.player_aim:
			player.player_model.player_aim.is_precise_aim = true

func on_exit_action():
	# Disable aim mode when exiting
	var weapon = player.player_model.active_weapon
	if weapon is RangedWeapon:
		if player.player_model.player_aim:
			player.player_model.player_aim.is_precise_aim = false

