extends LegsBehaviour

func update(input : InputPackage, delta : float):
	legs.current_action._update(input, delta)

func on_enter_behaviour(input : InputPackage):
	if legs.current_action.action_name != "run":
		switch_to("run", input)