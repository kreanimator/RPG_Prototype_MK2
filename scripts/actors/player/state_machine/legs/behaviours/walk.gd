extends LegsBehaviour

func update(input : InputPackage, delta : float):
	legs.current_action._update(input, delta)

func on_enter_behaviour(input : InputPackage):
	print("Entering Walk!")
	if legs.current_action.action_name != "walk":
		switch_to("walk", input)
