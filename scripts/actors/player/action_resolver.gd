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
			_execute_interact_intent()
		ActionIntent.IntentType.ATTACK:
			_execute_attack_intent()
		ActionIntent.IntentType.INVESTIGATE:
			_execute_investigate_intent()

func _execute_move_intent() -> void:
	execution_state = ExecutionState.NAVIGATING
	player.set_target_position(current_intent.target_position)
	player.player_visuals.cursor_manager.show_target_point(
		current_intent.target_position,
		current_intent.target_normal
	)

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

func _execute_attack_intent() -> void:
	var enemy = current_intent.target_object as Actor
	
	if not enemy or not is_instance_valid(enemy):
		intent_failed.emit(current_intent, "Invalid enemy target")
		_clear_intent()
		return
	
	var distance = player.global_position.distance_to(enemy.global_position)
	
	if current_intent.weapon_range > 0:
		if distance > current_intent.weapon_range:
			intent_failed.emit(current_intent, "Enemy out of range")
			_clear_intent()
			return
		else:
			execution_state = ExecutionState.EXECUTING_ACTION
			return
	else:
		if distance > 2.0:
			execution_state = ExecutionState.NAVIGATING
			player.set_target_position(enemy.global_position)
		else:
			execution_state = ExecutionState.EXECUTING_ACTION

func _execute_investigate_intent() -> void:
	execution_state = ExecutionState.NAVIGATING
	player.set_target_position(current_intent.target_position)

func update(delta: float) -> void:
	if not current_intent or execution_state == ExecutionState.IDLE:
		return
	
	match execution_state:
		ExecutionState.NAVIGATING:
			_update_navigation()
		ExecutionState.EXECUTING_ACTION:
			_monitor_behavior_completion()

func _update_navigation() -> void:
	# For interact intents, check if we're close enough
	if current_intent.intent_type == ActionIntent.IntentType.INTERACT:
		var interactable = current_intent.target_object as Interactable
		if interactable and is_instance_valid(interactable):
			var distance = player.global_position.distance_to(interactable.global_position)
			if distance <= interactable.interaction_zone_size:
				# Close enough, transition to executing action
				# The interact behavior will handle rotation
				execution_state = ExecutionState.EXECUTING_ACTION
				return
	
	# For other intents, wait for navigation to finish
	if player.nav_agent.is_navigation_finished():
		execution_state = ExecutionState.EXECUTING_ACTION

func _monitor_behavior_completion() -> void:
	if not _action_triggered:
		_action_triggered = true
		if current_intent.intent_type == ActionIntent.IntentType.INTERACT:
			_last_behavior = "interact"
		elif current_intent.intent_type == ActionIntent.IntentType.ATTACK:
			_last_behavior = "attack"
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
			if current_intent.intent_type == ActionIntent.IntentType.INTERACT:
				return "interact"
			elif current_intent.intent_type == ActionIntent.IntentType.ATTACK:
				return "attack"
			return current_intent.action_name
	
	return ""

func cancel_intent() -> void:
	_cancel_current_intent()
