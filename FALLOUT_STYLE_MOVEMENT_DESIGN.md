# Fallout-Style Movement and Interaction System Design

## Current Architecture Analysis

### Existing Components
1. **InputCollector** (`mouse_controller.gd`) - Handles mouse input and converts to actions
2. **PlayerModel** - Orchestrates state machines and updates
3. **TorsoMachine/LegsMachine** - Split body state machines
4. **TorsoBehaviour** - Individual behaviors (idle, walk, run, crouch, interact)
5. **Interactable** - Objects that can be interacted with
6. **GameManager** - Global state (MouseMode, MoveMode, GameState)
7. **NavigationAgent3D** - Pathfinding to target positions

### Current Flow
```
Mouse Click → InputCollector → InputPackage → PlayerModel → TorsoMachine → TorsoBehaviour
                                                           → LegsMachine → LegsBehaviour
```

## Problem Statement

Currently, clicking on an interactable or enemy doesn't automatically:
1. Move to interaction range
2. Turn to face the target
3. Execute the appropriate action (interact/attack)

The system needs a **goal-oriented action queue** that chains:
- Navigation → Positioning → Rotation → Action Execution

---

## Proposed Solution: Action Intent System

### Core Concept
Instead of directly setting actions, mouse clicks create **ActionIntents** that describe the desired outcome. A new **ActionResolver** component processes these intents and manages the multi-step execution.

### New Components

#### 1. ActionIntent (Resource/Class)
```gdscript
class_name ActionIntent
extends RefCounted

enum IntentType {
	MOVE_TO_POSITION,
	INTERACT_WITH_OBJECT,
	ATTACK_ENEMY,
	INVESTIGATE_POSITION
}

var intent_type: IntentType
var target_position: Vector3
var target_object: Node3D  # Interactable or Actor
var target_normal: Vector3 = Vector3.UP
var weapon_range: float = 0.0  # For attack intents
var requires_facing: bool = true
var action_name: String = ""  # "interact", "attack", etc.
```

#### 2. ActionResolver (Node)
```gdscript
class_name ActionResolver
extends Node

# Manages the execution pipeline for complex actions
var current_intent: ActionIntent = null
var execution_state: ExecutionState = ExecutionState.IDLE

enum ExecutionState {
	IDLE,
	NAVIGATING,
	POSITIONING,
	ROTATING,
	EXECUTING_ACTION,
	COMPLETED,
	FAILED
}

# State tracking
var target_reached: bool = false
var facing_target: bool = false
var in_range: bool = false
```

#### 3. Enhanced InputCollector
Refactor to create intents instead of direct actions:

```gdscript
func _handle_left_click(mouse_pos: Vector2) -> void:
	var result = Utils.get_camera_raycast_from_mouse(mouse_pos, player.camera_node.cam, 1)
	if not result:
		return
	
	var intent = _create_intent_from_click(result)
	if intent:
		player.player_model.action_resolver.set_intent(intent)
```

---

## Implementation Strategy

### Phase 1: Action Intent Creation

**File**: `scripts/actors/player/action_intent.gd` (NEW)
```gdscript
class_name ActionIntent
extends RefCounted

enum IntentType { MOVE, INTERACT, ATTACK, INVESTIGATE }

var intent_type: IntentType
var target_position: Vector3
var target_object: Node3D
var target_normal: Vector3 = Vector3.UP
var action_name: String = ""
var weapon_range: float = 0.0
var requires_facing: bool = true
var interaction_range: float = 1.5  # Default interaction distance

static func create_move_intent(pos: Vector3, normal: Vector3) -> ActionIntent:
	var intent = ActionIntent.new()
	intent.intent_type = IntentType.MOVE
	intent.target_position = pos
	intent.target_normal = normal
	intent.requires_facing = false
	return intent

static func create_interact_intent(interactable: Interactable, actor: Actor) -> ActionIntent:
	var intent = ActionIntent.new()
	intent.intent_type = IntentType.INTERACT
	intent.target_object = interactable
	intent.target_position = interactable.global_position
	intent.action_name = interactable.default_action
	intent.interaction_range = interactable.interaction_zone_size
	intent.requires_facing = true
	return intent

static func create_attack_intent(enemy: Actor, weapon_range: float) -> ActionIntent:
	var intent = ActionIntent.new()
	intent.intent_type = IntentType.ATTACK
	intent.target_object = enemy
	intent.target_position = enemy.global_position
	intent.action_name = "attack"
	intent.weapon_range = weapon_range
	intent.requires_facing = true
	return intent
```

### Phase 2: Action Resolver

**File**: `scripts/actors/player/action_resolver.gd` (NEW)
```gdscript
class_name ActionResolver
extends Node

signal intent_completed(intent: ActionIntent)
signal intent_failed(intent: ActionIntent, reason: String)

@export var player: Player
@export var rotation_speed: float = 8.0
@export var position_tolerance: float = 0.1
@export var angle_tolerance: float = 5.0  # degrees

var current_intent: ActionIntent = null
var execution_state: ExecutionState = ExecutionState.IDLE

enum ExecutionState {
	IDLE,
	NAVIGATING,
	POSITIONING,
	ROTATING,
	EXECUTING_ACTION,
	COMPLETED,
	FAILED
}

func set_intent(intent: ActionIntent) -> void:
	# Cancel current intent if any
	if current_intent:
		_cancel_current_intent()
	
	current_intent = intent
	execution_state = ExecutionState.IDLE
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
	
	# Check if already in range
	if interactable.can_interact():
		execution_state = ExecutionState.ROTATING
		return
	
	# Need to navigate to interaction range
	execution_state = ExecutionState.NAVIGATING
	player.set_target_position(current_intent.target_position)

func _execute_attack_intent() -> void:
	var enemy = current_intent.target_object as Actor
	var distance = player.global_position.distance_to(enemy.global_position)
	
	# Check weapon range
	if current_intent.weapon_range > 0:
		# Ranged weapon
		if distance > current_intent.weapon_range:
			intent_failed.emit(current_intent, "Enemy out of range")
			_clear_intent()
			return
		else:
			# In range, just rotate and attack
			execution_state = ExecutionState.ROTATING
			return
	else:
		# Melee weapon - need to get close
		if distance > 2.0:  # Melee range
			execution_state = ExecutionState.NAVIGATING
			player.set_target_position(enemy.global_position)
		else:
			execution_state = ExecutionState.ROTATING

func update(delta: float) -> void:
	if not current_intent or execution_state == ExecutionState.IDLE:
		return
	
	match execution_state:
		ExecutionState.NAVIGATING:
			_update_navigation()
		ExecutionState.ROTATING:
			_update_rotation(delta)
		ExecutionState.EXECUTING_ACTION:
			# Action execution is handled by behaviour system
			pass

func _update_navigation() -> void:
	if player.nav_agent.is_navigation_finished():
		# Navigation complete
		if current_intent.requires_facing:
			execution_state = ExecutionState.ROTATING
		else:
			_complete_intent()

func _update_rotation(delta: float) -> void:
	if not current_intent.target_object:
		_complete_intent()
		return
	
	var target_pos = current_intent.target_object.global_position
	var direction = (target_pos - player.global_position).normalized()
	direction.y = 0  # Keep rotation on horizontal plane
	
	if direction.length() < 0.01:
		_complete_intent()
		return
	
	var target_basis = Basis.looking_at(direction, Vector3.UP)
	player.basis = player.basis.slerp(target_basis, rotation_speed * delta)
	
	# Check if facing target
	var angle = rad_to_deg(player.basis.z.angle_to(-direction))
	if angle < angle_tolerance:
		_complete_intent()

func _complete_intent() -> void:
	execution_state = ExecutionState.COMPLETED
	intent_completed.emit(current_intent)
	_clear_intent()

func _cancel_current_intent() -> void:
	if current_intent:
		intent_failed.emit(current_intent, "Cancelled")
	_clear_intent()

func _clear_intent() -> void:
	current_intent = null
	execution_state = ExecutionState.IDLE

func is_executing() -> bool:
	return execution_state != ExecutionState.IDLE and execution_state != ExecutionState.COMPLETED

func get_current_action_for_input() -> String:
	"""Returns the action string that should be in InputPackage based on current intent state"""
	if not current_intent:
		return ""
	
	match execution_state:
		ExecutionState.NAVIGATING:
			# Return movement action based on GameManager.move_mode
			match GameManager.move_mode:
				GameManager.MoveMode.WALK:
					return "walk"
				GameManager.MoveMode.RUN:
					return "run"
				GameManager.MoveMode.CROUCH:
					return "crouch"
		ExecutionState.ROTATING:
			return "idle"  # Stand still while rotating
		ExecutionState.EXECUTING_ACTION:
			return current_intent.action_name
	
	return ""
```

### Phase 3: Refactor InputCollector

**File**: `scripts/core/mouse_controller.gd` (MODIFY)
```gdscript
extends Node
class_name InputCollector

@onready var player: Player = $".."

var _pending_right_click := false
var _pending_left_click := false
var _pending_mouse_pos := Vector2.ZERO

func collect_input() -> InputPackage:
	var new_input = InputPackage.new()

	# Right click: switch mouse mode
	if _pending_right_click:
		_pending_right_click = false
		_cycle_mouse_mode()
		player.player_visuals.cursor_manager.set_cursor_mode(GameManager.mouse_mode)

	# Left click: create intent
	if _pending_left_click and GameManager.can_perform_action:
		_pending_left_click = false
		_handle_left_click(_pending_mouse_pos)
	elif _pending_left_click:
		_pending_left_click = false

	# Get action from action resolver if it's executing an intent
	var action_resolver = player.player_model.action_resolver as ActionResolver
	if action_resolver and action_resolver.is_executing():
		var action = action_resolver.get_current_action_for_input()
		if action != "":
			new_input.actions.append(action)
	
	# Default idle
	if new_input.actions.is_empty():
		if GameManager.move_mode == GameManager.MoveMode.CROUCH:
			new_input.actions.append("crouch_idle")
		new_input.actions.append("idle")

	return new_input

func _handle_left_click(mouse_pos: Vector2) -> void:
	var result = Utils.get_camera_raycast_from_mouse(mouse_pos, player.camera_node.cam, 1)
	if not result:
		return
	
	var intent = _create_intent_from_click(result)
	if intent:
		var action_resolver = player.player_model.action_resolver as ActionResolver
		action_resolver.set_intent(intent)

func _create_intent_from_click(raycast_result: Dictionary) -> ActionIntent:
	var hit_pos = raycast_result["position"]
	var hit_normal = raycast_result.get("normal", Vector3.UP)
	var collider = raycast_result.get("collider")
	
	match GameManager.mouse_mode:
		GameManager.MouseMode.MOVE:
			return ActionIntent.create_move_intent(hit_pos, hit_normal)
		
		GameManager.MouseMode.INTERACT:
			# Check if we clicked on an interactable
			var interactable = _find_interactable(collider)
			if interactable:
				return ActionIntent.create_interact_intent(interactable, player)
			else:
				# No interactable, just move there
				return ActionIntent.create_move_intent(hit_pos, hit_normal)
		
		GameManager.MouseMode.ATTACK:
			# Check if we clicked on an enemy
			var enemy = _find_actor(collider)
			if enemy and player.is_hostile_to(enemy):
				var weapon_range = _get_current_weapon_range()
				return ActionIntent.create_attack_intent(enemy, weapon_range)
			else:
				print("No valid enemy target")
				return null
		
		GameManager.MouseMode.INVESTIGATE:
			var intent = ActionIntent.new()
			intent.intent_type = ActionIntent.IntentType.INVESTIGATE
			intent.target_position = hit_pos
			intent.action_name = "investigate"
			return intent
	
	return null

func _find_interactable(node: Node) -> Interactable:
	var current = node
	while current:
		if current.has_node("Interactable"):
			return current.get_node("Interactable") as Interactable
		# Check if node itself is Interactable
		if current is Interactable:
			return current as Interactable
		current = current.get_parent()
	return null

func _find_actor(node: Node) -> Actor:
	var current = node
	while current:
		if current is Actor:
			return current as Actor
		current = current.get_parent()
	return null

func _get_current_weapon_range() -> float:
	# Get from equipment manager or active weapon
	if player.equipment_manager and player.equipment_manager.current_weapon:
		return player.equipment_manager.current_weapon.range
	return 0.0  # Melee

func _input(event: InputEvent) -> void:
	if Utils.is_mouse_over_gui():
		return

	if event is InputEventMouseButton and event.is_action_pressed("right_click"):
		_pending_right_click = true

	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		_pending_left_click = true
		_pending_mouse_pos = event.position

func _cycle_mouse_mode() -> void:
	GameManager.mouse_mode = (int(GameManager.mouse_mode) + 1) % GameManager.MouseMode.keys().size() as GameManager.MouseMode
	print("mouse_mode:", GameManager.MouseMode.keys()[GameManager.mouse_mode])
```

### Phase 4: Integrate ActionResolver into PlayerModel

**File**: `scripts/actors/player/player_model.gd` (MODIFY)
```gdscript
# Add to existing @onready variables:
@onready var action_resolver: ActionResolver = $ActionResolver

# In update() function, add after area_awareness.contextualize(input):
func update(input : InputPackage, delta : float):
	# ... existing code ...
	
	area_awareness.contextualize(input)
	
	# NEW: Update action resolver
	action_resolver.update(delta)
	
	# ... rest of existing code ...
```

---

## Integration Steps

### Step 1: Create New Files
1. Create `scripts/actors/player/action_intent.gd`
2. Create `scripts/actors/player/action_resolver.gd`

### Step 2: Modify Existing Files
1. Refactor `scripts/core/mouse_controller.gd` (InputCollector)
2. Add ActionResolver node to PlayerModel in `player_model.gd`

### Step 3: Scene Setup
1. Open `scenes/player/player.tscn`
2. Add ActionResolver node as child of PlayerModel
3. Connect signals if needed

### Step 4: Testing
1. Test simple movement (should work as before)
2. Test clicking on interactables (should auto-navigate + interact)
3. Test clicking on enemies (should check range + navigate if needed)

---

## Benefits of This Approach

1. **No State Machine Changes** - TorsoBehaviour and LegsBehaviour remain unchanged
2. **Separation of Concerns** - Intent creation vs execution vs animation
3. **Extensible** - Easy to add new intent types (e.g., USE_ITEM, CAST_SPELL)
4. **Debuggable** - Clear execution states and signals
5. **Fallout-like Feel** - Click → auto-navigate → auto-face → action

---

## Future Enhancements

1. **Action Queue** - Allow multiple intents to be queued
2. **Smart Positioning** - Find optimal position around target (not just center)
3. **Interrupt Handling** - Cancel intent on damage/new input
4. **Visual Feedback** - Show path preview, range indicators
5. **Combat Integration** - AP cost checking before navigation
6. **Stealth Approach** - Different movement speeds when approaching enemies

---

## Example Usage Flow

### Scenario: Click on distant interactable

```
1. User clicks on chest (10m away)
2. InputCollector creates InteractIntent
3. ActionResolver receives intent
4. State: NAVIGATING
   - Sets nav_agent target
   - Returns "run" action to InputPackage
   - TorsoMachine switches to Run behaviour
5. Player navigates to chest
6. State: ROTATING
   - Smoothly rotates to face chest
   - Returns "idle" action
7. State: COMPLETED
   - Triggers interact behaviour
   - InteractBehaviour plays animation
   - Interaction fires
```

This creates the seamless Fallout-style experience you're looking for!
