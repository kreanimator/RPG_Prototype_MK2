extends TorsoBehaviour


func transition_logic(input : InputPackage) -> String:
	# Check if weapon is still valid - if not, exit aim behavior to idle
	var model = player.player_model as PlayerModel
	if not model or not is_instance_valid(model.active_weapon):
		return "idle"
	
	var weapon = model.active_weapon as RangedWeapon
	if not weapon:
		return "idle"
	
	map_with_dictionary(input)
	return best_input_that_can_be_paid(input)
