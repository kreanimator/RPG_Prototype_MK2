extends Node
class_name ActionResolver

signal intent_completed(intent: ActionIntent)
signal intent_failed(intent: ActionIntent, reason: String)

@export var player: Player

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
	if not player:
		player = get_parent().get_parent() as Player

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
	execution_state = ExecutionState.NAVIGATING
	player.set_target_position(current_intent.target_position)
	player.player_visuals.cursor_manager.show_target_point(
		current_intent.target_position,
		current_intent.target_normal
	)

# -------------------------
# INTERACT (unchanged)
# -------------------------
func _execute_interact_intent() -> void:
	var interactable = current_intent.target_object as Interactable

	if not interactable or not is_instance_valid(interactable):
		intent_failed.emit(current_intent, "Invalid interactable")
		_clear_intent()
		return

	# Store the target interactable on the player
	player.current_interactable = interactable

	# Check distance to interactable
	var distance = player.global_position.distance_to(interactable.global_position)
	if distance <= interactable.interaction_zone_size:
		# Already in range, go directly to executing
		execution_state = ExecutionState.EXECUTING_ACTION
		return

	# Need to navigate closer
	execution_state = ExecutionState.NAVIGATING
	player.set_target_position(current_intent.target_position)

# -------------------------
# ATTACK (fixed: move into range, then attack; never "out of range" fail)
# -------------------------
func _execute_attack_intent() -> void:
	var enemy := current_intent.target_object as Actor

	if not enemy or not is_instance_valid(enemy):
		intent_failed.emit(current_intent, "Invalid enemy target")
		_clear_intent()
		return

	# Cache enemy position into intent (so navigation has something even if enemy ref changes)
	current_intent.target_position = enemy.global_position

	# Decide desired melee/ranged approach distance
	# - if weapon_range provided: use it (melee should pass 1.6 etc)
	# - else fallback to 2.0 (your old default)
	var desired_range := current_intent.weapon_range
	if desired_range <= 0.0:
		desired_range = 2.0

	var distance := player.global_position.distance_to(enemy.global_position)

	if distance <= desired_range:
		# Already in range -> execute attack
		execution_state = ExecutionState.EXECUTING_ACTION
		return

	# Out of range -> navigate closer (same "move then act" style as interact)
	execution_state = ExecutionState.NAVIGATING
	player.set_target_position(enemy.global_position)

# -------------------------
# INVESTIGATE (simple: move to clicked position; like Fallout 2 "research")
# -------------------------
func _execute_investigate_intent() -> void:
	execution_state = ExecutionState.NAVIGATING
	player.set_target_position(current_intent.target_position)
	player.player_visuals.cursor_manager.show_target_point(
		current_intent.target_position,
		current_intent.target_normal
	)

func update(delta: float) -> void:
	if not current_intent or execution_state == ExecutionState.IDLE:
		return

	match execution_state:
		ExecutionState.NAVIGATING:
			_update_navigation()
		ExecutionState.EXECUTING_ACTION:
			_monitor_behavior_completion()

func _update_navigation() -> void:
	# Keep the EXACT interact logic (unchanged)
	if current_intent.intent_type == ActionIntent.IntentType.INTERACT:
		var interactable = current_intent.target_object as Interactable
		if interactable and is_instance_valid(interactable):
			var distance = player.global_position.distance_to(interactable.global_position)
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

		var distance := player.global_position.distance_to(enemy.global_position)
		if distance <= desired_range:
			# Close enough to attack
			execution_state = ExecutionState.EXECUTING_ACTION
			return

		# Enemy moved? keep chasing
		player.set_target_position(enemy.global_position)
		return

	# For MOVE / INVESTIGATE: wait for navigation finished
	if player.nav_agent.is_navigation_finished():
		execution_state = ExecutionState.EXECUTING_ACTION

func _monitor_behavior_completion() -> void:
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
		var current_behavior = player.player_model.torso_machine.current_behaviour.behaviour_name
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
			match GameManager.move_mode:
				GameManager.MoveMode.WALK:
					return "walk"
				GameManager.MoveMode.RUN:
					return "run"
				GameManager.MoveMode.CROUCH:
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


func cancel_intent() -> void:
	_cancel_current_intent()
