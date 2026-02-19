extends TorsoBehaviour

var _target: Actor = null
var aim: PlayerAim

# Store default unarmed actions
var _default_actions: Dictionary = {}
var _weapon_actions: Dictionary = {}
var _using_weapon_actions: bool = false

func update(input : InputPackage, delta : float):
	choose_action(input)
	if current_action:
		current_action.update(input, delta)

func transition_logic(input: InputPackage) -> String:
	map_with_dictionary(input)
	
	# Handle turn action completion
	if current_action != null and current_action.action_name == "turn":
		if current_action.animation_ended():
			_start_attack(input)
		return "okay"
	
	# Handle ranged weapon flow: turn -> aim -> shoot -> (back to idle)
	if _using_weapon_actions:
		if current_action != null and current_action.action_name == "shoot" and current_action.animation_ended():
			# After shooting, return to idle (no exit action for ranged)
			return best_input_that_can_be_paid(input)
		return "okay"
	
	# Normal unarmed attack logic: turn -> enter -> hit -> exit
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
	var weapon = player.player_model.active_weapon
	
	if weapon is RangedWeapon:
		# Ranged weapon flow: aim -> shoot
		switch_action_to("aim", input)
	else:
		# Unarmed flow: enter -> hit
		switch_action_to("enter", input)

func choose_action(input : InputPackage):
	if not current_action:
		return
	
	# Ranged weapon flow
	if _using_weapon_actions:
		if current_action.action_name == "aim" and current_action.animation_ended():
			switch_action_to("shoot", input)
		# shoot -> idle handled in transition_logic
		return
	
	# Unarmed flow
	if current_action.action_name == "enter" and current_action.animation_ended():
		switch_action_to("hit", input)
	if current_action.action_name == "hit" and current_action.animation_ended():
		switch_action_to("exit", input)

func get_action_cost() -> int:
	# Get action cost based on equipped weapon
	var weapon = player.player_model.active_weapon
	var stats
	if weapon is RangedWeapon:
		var ranged_weapon = weapon as RangedWeapon
		# For turn-based: single shot costs less than burst
		if ranged_weapon.fire_mode == RangedWeapon.FireMode.BURST:
			# Burst costs more AP (e.g., 2x single shot cost)
			stats = player.player_model.stats_manager as StatsManager
			return stats.get_unarmed_action_cost() * 2
		else:
			# Single shot costs same as unarmed
			stats = player.player_model.stats_manager as StatsManager
			return stats.get_unarmed_action_cost()
	
	# Unarmed or melee weapon
	stats = player.player_model.stats_manager as StatsManager
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

#region ----- Dynamic Action Swapping -----

func _init_behaviour():
	super._init_behaviour()
	# Store default unarmed actions
	_store_default_actions()

func _store_default_actions() -> void:
	# Store current actions as default (unarmed)
	_default_actions = actions.duplicate()

func swap_to_weapon_actions(weapon_scene_path: String) -> void:
	"""Swap attack actions to weapon-specific actions from weapon scene"""
	if weapon_scene_path.is_empty():
		return
	
	# Load weapon scene
	var weapon_scene = load(weapon_scene_path) as PackedScene
	if not weapon_scene:
		push_error("Attack: Failed to load weapon scene: " + weapon_scene_path)
		return
	
	# Find Attack node in weapon scene
	var weapon_instance = weapon_scene.instantiate()
	var attack_node = _find_attack_node(weapon_instance)
	if not attack_node:
		weapon_instance.queue_free()
		push_warning("Attack: No Attack node found in weapon scene: " + weapon_scene_path)
		return
	
	# Store weapon actions
	_weapon_actions = {}
	for child in attack_node.get_children():
		if child is TorsoAction:
			# Clone the action node (deep copy to preserve all properties)
			var action_copy = child.duplicate(true)  # deep = true to copy all properties
			
			# Initialize action with behavior references (same as _init_behaviour does)
			action_copy.parent_behaviour = self
			action_copy.player = player
			action_copy.combat = combat
			action_copy.torso = torso
			action_copy.animations_source = animations_source
			action_copy.simple_torso = simple_torso
			action_copy.torso_anim_settings = torso_anim_settings
			
			# Set animation duration if animation is set
			if action_copy.animation and not action_copy.animation.is_empty():
				if animations_source.has_animation(action_copy.animation):
					action_copy.animation_duration = animations_source.get_animation(action_copy.animation).length
			
			_weapon_actions[action_copy.action_name] = action_copy
	
	weapon_instance.queue_free()
	
	# Swap to weapon actions
	actions = _weapon_actions.duplicate()
	_using_weapon_actions = true
	
	print("[Attack] Swapped to weapon actions. Available actions: ", actions.keys())

func swap_to_unarmed_actions() -> void:
	"""Restore default unarmed actions"""
	actions = _default_actions.duplicate()
	_weapon_actions.clear()
	_using_weapon_actions = false
	print("[Attack] Swapped to unarmed actions. Available actions: ", actions.keys())

func _find_attack_node(node: Node) -> Node:
	"""Recursively find Attack node in weapon scene"""
	if node.name == "Attack":
		return node
	for child in node.get_children():
		var found = _find_attack_node(child)
		if found:
			return found
	return null

#endregion

#region ----- Target Caching -----

func _get_cached_attack_target() -> Dictionary:
	"""Return cached target for actions to use"""
	if _target != null and is_instance_valid(_target):
		return {
			"target": _target,
			"position": _target.global_position
		}
	return {}

#endregion
