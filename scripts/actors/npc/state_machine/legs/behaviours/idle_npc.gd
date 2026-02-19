extends LegsBehaviourNPC

func update(input : AIInputPackage, _delta : float):
	# For NPCs, we don't need complex turning logic
	# Just ensure we're in idle action
	if legs.current_action.action_name != "idle":
		switch_to("idle", input)

func on_enter_behaviour(input : AIInputPackage):
	print("Entering Idle!")
	if legs.current_action.action_name != "idle":
		switch_to("idle", input)
