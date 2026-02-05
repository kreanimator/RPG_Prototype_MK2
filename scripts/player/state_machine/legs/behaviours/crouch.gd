extends LegsBehaviour

func update(input : InputPackage, delta : float):
	legs.current_action._update(input, delta)

func on_enter_behaviour(input : InputPackage):
	print("Entering Crouch!")
	if legs.current_action.action_name != "crouch":
		switch_to("crouch", input)
