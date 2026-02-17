extends TorsoBehaviour

var _target: Actor = null
var aim: PlayerAim

func update(input : InputPackage, delta : float):
	choose_action(input)
	current_action.update(input, delta)

func transition_logic(input: InputPackage) -> String:
	map_with_dictionary(input)
	
	# Handle turn action completion
	if current_action != null and current_action.action_name == "turn":
		if current_action.animation_ended():
			_start_attack(input)
		return "okay"
	
	# Normal attack logic
	if current_action != null and current_action.action_name == "exit" and current_action.animation_ended():
		return best_input_that_can_be_paid(input)
	return "okay"

func on_enter_behaviour(input : InputPackage):
	if GameManager.game_state == GameManager.GameState.COMBAT:
		player.player_model.resources.spend_action_points(get_action_cost())
	
	# Get target from ActionResolver
	var resolver := player.player_model.action_resolver as ActionResolver
	if resolver and resolver.current_intent and resolver.current_intent.intent_type == ActionIntent.IntentType.ATTACK:
		_target = resolver.current_intent.target_object as Actor
	
	# Set target in PlayerAim for turning
	aim = player.player_model.player_aim as PlayerAim
	if aim and _target:
		aim.set_target_node(_target, false)  # Don't auto-turn, we'll handle it with turn action
	
	# Check if we need to turn first
	if needs_turning():
		switch_action_to("turn", input)
		return
	
	# No turning needed, proceed with attack
	_start_attack(input)

func _start_attack(input: InputPackage) -> void:
	switch_action_to("enter", input)

func choose_action(input : InputPackage):
	if current_action.action_name == "enter" and current_action.animation_ended():
		switch_action_to("hit", input)
	if current_action.action_name == "hit" and current_action.animation_ended():
		switch_action_to("exit", input)

func get_action_cost() -> int:
	var stats := player.player_model.stats_manager as StatsManager
	return stats.get_unarmed_action_cost()


func get_turn_target_position() -> Vector3:
	# Used by Turn action to know where to face.
	if _target != null and is_instance_valid(_target):
		return _target.global_position
	# Fallback: forward direction
	var forward_dir := -player.global_transform.basis.z
	return player.global_position + forward_dir


func needs_turning() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	
	var target_pos := _target.global_position
	var to_target := player.global_position.direction_to(target_pos)
	var angle := player.global_basis.z.angle_to(to_target)
	return angle > 0.3  # ~17 degrees threshold

func on_exit_behaviour():
	super.on_exit_behaviour()
	_target = null
	if aim:
		aim.clear_target()
