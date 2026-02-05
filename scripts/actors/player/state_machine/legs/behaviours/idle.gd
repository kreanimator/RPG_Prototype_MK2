extends LegsBehaviour

func update(input : InputPackage, _delta : float):
	# For point-and-click, we don't need complex turning logic
	# Just ensure we're in idle action
	if legs.current_action.action_name != "idle":
		switch_to("idle", input)

func on_enter_behaviour(input : InputPackage):
	print("Entering Idle!")
	if legs.current_action.action_name != "idle":
		switch_to("idle", input)
