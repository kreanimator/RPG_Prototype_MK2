extends TorsoBehaviour


func transition_logic(input : InputPackage) -> String:
	map_with_dictionary(input)
	if current_action.action_name == "exit" and current_action.animation_ended():
		return best_input_that_can_be_paid(input)
	return "okay"


func update(input : InputPackage, delta : float):
	choose_action(input)
	#print(current_action.action_name)
	current_action.update(input, delta)


func choose_action(input : InputPackage):
	if current_action.action_name == "enter" and current_action.animation_ended():
		switch_action_to("cycle", input)
	if input.actions.has("go_up") and current_action.action_name != "exit":
		switch_action_to("exit", input)


func on_enter_behaviour(input : InputPackage):
	switch_action_to("enter", input)


func _on_exit_requested() -> void:
	if current_action.action_name != "exit":
		var input := InputPackage.new()
		input.actions.append("go_up")
		switch_action_to("exit", input)
