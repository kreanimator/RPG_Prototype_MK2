extends TorsoAction

# Reload action for ranged weapons

func setup_animator(_input : InputPackage):
	# Play reload animation
	if animation.is_empty():
		animation = "Reload"  # Default reload animation name
	
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0.0)
		torso_anim_settings.play("simple", 0.15)
	
	if parent_behaviour.legs.legs_anim_settings.current_animation == "simple":
		parent_behaviour.legs.simple_animator.play(animation, 0.15)
	else:
		parent_behaviour.legs.simple_animator.play(animation, 0.0)
		parent_behaviour.legs.legs_anim_settings.play("simple", 0.15)
	
	# Start reload process
	_start_reload()

func _start_reload() -> void:
	var weapon = player.player_model.active_weapon
	if not weapon is RangedWeapon:
		return
	
	var ranged_weapon = weapon as RangedWeapon
	ranged_weapon.reload()

func update(_input : InputPackage, _delta : float):
	# Check if reload is complete
	var weapon = player.player_model.active_weapon
	if weapon is RangedWeapon:
		var ranged_weapon = weapon as RangedWeapon
		if not ranged_weapon.is_reloading:
			# Reload complete, animation should end naturally
			pass

