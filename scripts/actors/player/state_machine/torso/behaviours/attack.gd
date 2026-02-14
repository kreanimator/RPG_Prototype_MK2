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
	switch_action_to("enter", input)

func choose_action(input : InputPackage):
	if current_action.action_name == "enter" and current_action.animation_ended():
		switch_action_to("hit", input)
	if current_action.action_name == "hit" and current_action.animation_ended():
		switch_action_to("exit", input)
