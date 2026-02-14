extends TorsoBehaviour

func update(input : InputPackage, delta : float):
	choose_action(input)
	#print(current_action.action_name)
	current_action.update(input, delta)

func transition_logic(input: InputPackage) -> String:
	map_with_dictionary(input)
	if current_action.action_name == "exit" and current_action.animation_ended():
		return best_input_that_can_be_paid(input)
	return "okay"

func on_enter_behaviour(input : InputPackage):
	if GameManager.game_state == GameManager.GameState.COMBAT:
		player.player_model.resources.spend_action_points(get_action_cost())
	switch_action_to("enter", input)

func choose_action(input : InputPackage):
	if current_action.action_name == "enter" and current_action.animation_ended():
		switch_action_to("hit", input)
	if current_action.action_name == "hit" and current_action.animation_ended():
		switch_action_to("exit", input)

func get_action_cost() -> int:
	var stats := player.player_model.stats_manager as StatsManager
	return stats.get_unarmed_action_cost()
