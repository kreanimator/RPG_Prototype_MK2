extends Node
class_name ActionResolver

signal intent_completed(intent: ActionIntent)
signal intent_failed(intent: ActionIntent, reason: String)

# Generic actor reference (works for Player, enemies, NPCs, etc.)
var actor: Actor = null
# Model reference (PlayerModel or HumanoidModel)
var model: Node = null  # Can be PlayerModel or HumanoidModel
# Move mode for navigation
# For Player: uses GameManager.MoveMode
# For NPCs/enemies: uses Actor.ActorMoveMode
var move_mode: int = GameManager.MoveMode.WALK

var current_intent: ActionIntent = null
var execution_state: ExecutionState = ExecutionState.IDLE
var _action_triggered: bool = false
var _last_behavior: String = ""

enum ExecutionState {
	IDLE,
	NAVIGATING,
	EXECUTING_ACTION,
	COMPLETED
}

func _ready() -> void:
	# Auto-detect actor from parent hierarchy
	if not actor:
		var parent = get_parent()
		if parent:
			# Try to find Actor in parent chain
			if parent is Actor:
				actor = parent as Actor
			elif parent.get_parent() is Actor:
				actor = parent.get_parent() as Actor
		
		# Auto-detect model
		if actor:
			# Try PlayerModel first (for Player)
			if actor is Player:
				var player = actor as Player
				model = player.get_node_or_null("PlayerModel")
			else:
				# Try HumanoidModel (for enemies/NPCs)
				# Search all children for HumanoidModel
				for child in actor.get_children():
					if child is HumanoidModel:
						model = child
						break
		
		# Set move mode based on actor type
		if actor is Player:
			# Player uses GameManager.move_mode
			move_mode = GameManager.move_mode
		else:
			# NPCs/enemies: read move_mode from their model (uses Actor.ActorMoveMode)
			if model is HumanoidModel:
				move_mode = (model as HumanoidModel).move_mode
			else:
				move_mode = Actor.ActorMoveMode.WALK

func set_intent(intent: ActionIntent) -> void:
	if current_intent:
		_cancel_current_intent()

	current_intent = intent
	execution_state = ExecutionState.IDLE
	_action_triggered = false
	_last_behavior = ""
	_start_intent_execution()

func _start_intent_execution() -> void:
	if not current_intent:
		return

	match current_intent.intent_type:
		ActionIntent.IntentType.MOVE:
			_execute_move_intent()
		ActionIntent.IntentType.INTERACT:
			_execute_interact_intent() # KEEP AS-IS
		ActionIntent.IntentType.ATTACK:
			_execute_attack_intent()   # FIXED
		ActionIntent.IntentType.INVESTIGATE:
			_execute_investigate_intent() # simple "Fallout2 style" move

func _execute_move_intent() -> void:
	if not actor:
		return
	
	execution_state = ExecutionState.NAVIGATING
	actor.set_target_position(current_intent.target_position)
	
	# Player-specific: show target point VFX (optional for NPCs)
	if actor is Player:
		var player = actor as Player
		if player.player_visuals and player.player_visuals.cursor_manager:
			var snapped_pos := actor.nav_agent.target_position
			player.player_visuals.cursor_manager.show_target_point(snapped_pos, Vector3.UP)

# -------------------------
# INTERACT (unchanged)
# -------------------------
func _execute_interact_intent() -> void:
	if not actor:
		return
	
	var interactable = current_intent.target_object as Interactable

	if not interactable or not is_instance_valid(interactable):
		intent_failed.emit(current_intent, "Invalid interactable")
		_clear_intent()
		return

	# Store the target interactable on the actor
	actor.current_interactable = interactable

	# Check distance to interactable
	var distance = actor.global_position.distance_to(interactable.global_position)
	if distance <= interactable.interaction_zone_size:
		# Already in range, go directly to executing
		execution_state = ExecutionState.EXECUTING_ACTION
		return

	# Need to navigate closer
	execution_state = ExecutionState.NAVIGATING
	actor.set_target_position(current_intent.target_position)

# -------------------------
# ATTACK (fixed: move into range, then attack; never "out of range" fail)
# -------------------------
func _execute_attack_intent() -> void:
	if not actor:
		return
	
	var enemy := current_intent.target_object as Actor

	if not enemy or not is_instance_valid(enemy):
		intent_failed.emit(current_intent, "Invalid enemy target")
		_clear_intent()
		return

	# Decide desired melee/ranged approach distance
	# - if weapon_range provided: use it (melee should pass 1.6 etc)
	# - else fallback to 2.0 (your old default)
	var desired_range := current_intent.weapon_range
	if desired_range <= 0.0:
		desired_range = 2.0

	var distance := actor.global_position.distance_to(enemy.global_position)

	if distance <= desired_range:
		# Already in range -> execute attack
		execution_state = ExecutionState.EXECUTING_ACTION
		return

	# Out of range -> navigate to a position at weapon_range distance from enemy
	# Calculate direction from enemy to actor, then position at desired_range distance
	var direction_to_actor := (actor.global_position - enemy.global_position).normalized()
	var approach_position := enemy.global_position + direction_to_actor * desired_range
	
	# Cache the approach position (not enemy position) for navigation
	current_intent.target_position = approach_position
	
	# Navigate to approach position
	execution_state = ExecutionState.NAVIGATING
	actor.set_target_position(approach_position)

# -------------------------
# INVESTIGATE (simple: move to clicked position; like Fallout 2 "research")
# -------------------------
func _execute_investigate_intent() -> void:
	if not actor:
		return
	
	execution_state = ExecutionState.NAVIGATING
	actor.set_target_position(current_intent.target_position)
	
	# Player-specific: show target point VFX (optional for NPCs)
	if actor is Player:
		var player = actor as Player
		if player.player_visuals and player.player_visuals.cursor_manager:
			var snapped_pos := actor.nav_agent.target_position
			player.player_visuals.cursor_manager.show_target_point(snapped_pos, Vector3.UP)

func update(_delta: float) -> void:
	if not current_intent or execution_state == ExecutionState.IDLE:
		return

	match execution_state:
		ExecutionState.NAVIGATING:
			_update_navigation()
		ExecutionState.EXECUTING_ACTION:
			_monitor_behavior_completion()

func _update_navigation() -> void:
	if not actor:
		return
	
	# Keep the EXACT interact logic (unchanged)
	if current_intent.intent_type == ActionIntent.IntentType.INTERACT:
		var interactable = current_intent.target_object as Interactable
		if interactable and is_instance_valid(interactable):
			var distance = actor.global_position.distance_to(interactable.global_position)
			if distance <= interactable.interaction_zone_size:
				execution_state = ExecutionState.EXECUTING_ACTION
				return

	# For ATTACK: move into weapon_range, not just "navigation finished"
	elif current_intent.intent_type == ActionIntent.IntentType.ATTACK:
		var enemy := current_intent.target_object as Actor
		if not enemy or not is_instance_valid(enemy):
			intent_failed.emit(current_intent, "Enemy disappeared")
			_clear_intent()
			return

		var desired_range := current_intent.weapon_range
		if desired_range <= 0.0:
			desired_range = 2.0

		var distance := actor.global_position.distance_to(enemy.global_position)
		if distance <= desired_range:
			# Close enough to attack
			execution_state = ExecutionState.EXECUTING_ACTION
			return

		# Enemy moved? keep chasing
		actor.set_target_position(enemy.global_position)
		return

	# For MOVE / INVESTIGATE: wait for navigation finished
	if actor.nav_agent and actor.nav_agent.is_navigation_finished():
		execution_state = ExecutionState.EXECUTING_ACTION

func _monitor_behavior_completion() -> void:
	if not model:
		return
	
	if not _action_triggered:
		_action_triggered = true
		if current_intent.intent_type == ActionIntent.IntentType.INTERACT:
			_last_behavior = "interact"
		elif current_intent.intent_type == ActionIntent.IntentType.ATTACK:
			_last_behavior = "attack"
		elif current_intent.intent_type == ActionIntent.IntentType.INVESTIGATE:
			_last_behavior = "investigate"
		else:
			_last_behavior = current_intent.action_name
	else:
		# Check if behavior has completed
		# Works for both PlayerModel and HumanoidModel (both have torso_machine)
		var torso_machine = model.get("torso_machine")
		if torso_machine and torso_machine.current_behaviour:
			var current_behavior = torso_machine.current_behaviour.behaviour_name
			if current_behavior != _last_behavior:
				_complete_intent()

func _complete_intent() -> void:
	intent_completed.emit(current_intent)
	_clear_intent()

func _cancel_current_intent() -> void:
	if current_intent:
		intent_failed.emit(current_intent, "Cancelled")
	_clear_intent()

func _clear_intent() -> void:
	current_intent = null
	execution_state = ExecutionState.IDLE
	_action_triggered = false
	_last_behavior = ""

func is_executing() -> bool:
	return execution_state != ExecutionState.IDLE and execution_state != ExecutionState.COMPLETED

func get_current_action_for_input() -> String:
	if not current_intent:
		return ""

	match execution_state:
		ExecutionState.NAVIGATING:
			# Use move_mode (set based on actor type)
			# For Player, read directly from GameManager.move_mode (always up-to-date)
			# For NPCs/enemies, read from their model's move_mode (can be changed dynamically)
			var current_move_mode = move_mode
			if actor is Player:
				current_move_mode = GameManager.move_mode
			elif model is HumanoidModel:
				# Read from model's move_mode (allows AI to change it dynamically)
				current_move_mode = (model as HumanoidModel).move_mode
			
			# Both GameManager.MoveMode and Actor.ActorMoveMode have the same integer values
			# (WALK=0, RUN=1, CROUCH=2), so we can match against the integer directly
			match current_move_mode:
				GameManager.MoveMode.WALK, Actor.ActorMoveMode.WALK:
					return "walk"
				GameManager.MoveMode.RUN, Actor.ActorMoveMode.RUN:
					return "run"
				GameManager.MoveMode.CROUCH, Actor.ActorMoveMode.CROUCH:
					return "crouch"

		ExecutionState.EXECUTING_ACTION:
			# IMPORTANT:
			# Only emit the action ONCE to enter the behaviour.
			# After that, return "" so InputCollector falls back to idle
			# while we keep monitoring behaviour completion.
			if _action_triggered:
				return ""

			match current_intent.intent_type:
				ActionIntent.IntentType.INTERACT:
					return "interact"
				ActionIntent.IntentType.ATTACK:
					return "attack"
				ActionIntent.IntentType.INVESTIGATE:
					return ""
				_:
					return current_intent.action_name

	return ""

func set_actor(_actor: Actor) -> void:
	"""Set the actor reference (can be called manually if auto-detection fails)"""
	actor = _actor
	
	# Auto-detect model based on actor type
	if actor is Player:
		var player = actor as Player
		model = player.get_node_or_null("PlayerModel")
		# Update move_mode from GameManager for player
		move_mode = GameManager.move_mode
	else:
		# For enemies/NPCs, find HumanoidModel
		for child in actor.get_children():
			if child is HumanoidModel:
				model = child
				break
		# NPCs/enemies: read move_mode from their model (uses Actor.ActorMoveMode)
		if model is HumanoidModel:
			move_mode = (model as HumanoidModel).move_mode
		else:
			move_mode = Actor.ActorMoveMode.WALK

func set_model(_model: Node) -> void:
	"""Set the model reference directly (PlayerModel or HumanoidModel)"""
	model = _model


func cancel_intent() -> void:
	_cancel_current_intent()
