# AI Architecture Plan for NPCs

## Overview
This document outlines the architecture for implementing AI for NPCs (enemies, allies, neutral characters) in the RPG prototype. The system is designed to work in both **free movement mode** (investigation/exploration) and **turn-based combat mode**.

## Key Design Principles

1. **Dual Mode Operation**: AI works differently in combat vs. exploration
   - **Free Movement Mode**: NPCs can move, interact, and act freely
   - **Combat Mode**: NPCs only act on their turn (respecting turn order)

2. **Reuse Existing Systems**: Leverage `ActionResolver`, `ActionIntent`, and state machines
3. **Modular Design**: AI brain is swappable, behaviors are composable
4. **Separation of Concerns**: Decision making vs. execution vs. animation

---

## 1. AI Brain Component (`AIBrain` or `AIController`)

### Purpose
Central decision-making component for NPCs that evaluates situations and generates action intents.

### Location
- Node on the actor (similar to `AIInputCollector`)
- Can be swapped per NPC type (aggressive, defensive, passive, etc.)

### Responsibilities
- **Situation Evaluation**: Assess current state (health, AP, enemies, allies, distance, game state)
- **Action Selection**: Choose next action (move, attack, interact, wait, flee)
- **Action Planning**: Plan sequences (path to target → attack, investigate → interact)
- **Priority Management**: Handle competing goals (survival > combat > objectives)
- **Mode Awareness**: Know if in combat or free movement mode

### Key Methods
```gdscript
func evaluate() -> Dictionary  # Returns current situation assessment
func decide_action() -> ActionIntent  # Generates next action intent
func update(delta: float) -> void  # Called every frame (mode-dependent)
func on_turn_start() -> void  # Called when NPC's turn begins (combat mode)
func on_turn_end() -> void  # Called when NPC's turn ends (combat mode)
```

---

## 2. Perception/Awareness System

### Current State
- `AreaAwareness` exists but may need extension for AI needs

### Enhancements Needed
- **Enemy Tracking**: Maintain list of visible/known enemies
- **Threat Assessment**: Calculate threat levels (distance, damage potential, health)
- **Ally Awareness**: Track friendly units for coordination
- **Object Detection**: Find interactable objects, loot, cover
- **Line of Sight**: Raycast checks for visibility
- **Memory System**: Remember last known positions, patrol routes
- **Spatial Awareness**: Understand environment (cover, chokepoints, escape routes)

### Integration
- `AIBrain` queries `AreaAwareness` for perception data
- Can extend `AreaAwareness` or create `AIPerception` component

---

## 3. AI Decision Flow

### Free Movement Mode (Investigation/Exploration)
```
Every Frame:
  AIBrain.update(delta)
    → Evaluate Situation (perception, state, objectives)
    → Generate Intent (ActionIntent: MOVE/INTERACT/INVESTIGATE)
    → Pass to ActionResolver
    → ActionResolver executes (navigation, interactions)
    → AIInputCollector.collect_input() reads current state
    → Generates AIInputPackage with behaviour_names
    → State machine responds with animations
```

### Combat Mode (Turn-Based)
```
On NPC's Turn:
  TurnController signals "active_actor_changed" → NPC's turn
  AIBrain.on_turn_start()
    → Evaluate Situation (combat-specific)
    → Generate Intent (ActionIntent: ATTACK/MOVE/WAIT)
    → Pass to ActionResolver
    → ActionResolver executes (respects AP costs)
    → When AP depleted or action complete → turn ends
  
Between Turns:
  AIBrain.update(delta) - LIMITED
    → Only updates perception/memory
    → Does NOT generate new intents
    → Can still respond to damage (hit animation)
```

---

## 4. Integration Points

### A. AIBrain → ActionResolver
- `AIBrain` creates `ActionIntent` objects (same as player)
- NPCs use the same `ActionResolver` as the player
- Handles navigation, attack ranges, interactions
- **Mode Check**: In combat, only generates intents on NPC's turn

### B. AIBrain → AIInputCollector
- `AIInputCollector.collect_input()` queries `AIBrain` for current decision
- `AIBrain` provides: target, move direction, attack intent, etc.
- `AIInputCollector` converts to `AIInputPackage` with `behaviour_names`
- **Mode Check**: In combat, only queries if it's NPC's turn

### C. Turn-Based Integration
- `AIBrain` listens to `TurnController.active_actor_changed` signal
- When `current_actor == self` → `on_turn_start()`
- When turn ends → `on_turn_end()`
- Between turns: AI is "frozen" (no new decisions, but can react to damage)

### D. Game State Awareness
- `AIBrain` checks `GameManager.game_state`
- `INVESTIGATION`: Free movement mode
- `COMBAT`: Turn-based mode
- Different behaviors per mode

---

## 5. AI Behavior Types (Modular, Swappable)

### A. Combat AI
- **Target Selection**: Closest, weakest, highest threat, most dangerous
- **Attack Range Management**: Move to optimal range, maintain distance
- **Cover/Positioning**: Seek cover, flank enemies, avoid being surrounded
- **Weapon Selection**: Choose best weapon for situation
- **AP Management**: Plan actions within AP budget

### B. Movement AI
- **Pathfinding**: Navigate to targets using NavigationAgent3D
- **Obstacle Avoidance**: Dynamic obstacle avoidance
- **Formation Movement**: Group coordination (if multiple NPCs)
- **Patrol Routes**: Follow predefined paths when idle

### C. Interaction AI
- **Object Interaction**: Prioritize interactable objects
- **Dialogue Triggers**: Initiate conversations
- **Loot Collection**: Pick up items
- **Environmental Interaction**: Use switches, doors, etc.

### D. State-Based AI (FSM)
- **States**: 
  - `IDLE`: Stand still, look around
  - `PATROL`: Follow patrol route
  - `INVESTIGATE`: Move to suspicious area/object
  - `COMBAT`: Engage enemies
  - `FLEE`: Run away when health low
  - `SEARCH`: Look for hidden enemies/objects
- **Transitions**: Based on conditions (health, enemy proximity, etc.)
- **Each State**: Has its own decision logic

---

## 6. Proposed Structure

```
DustWalker (Actor)
├── AIBrain (new component)
│   ├── Current State (IDLE/COMBAT/PATROL/etc.)
│   ├── Current Mode (FREE_MOVEMENT/TURN_BASED)
│   ├── Target Selection Logic
│   ├── Decision Tree/Behavior Tree
│   ├── Memory/Blackboard (shared data)
│   └── Turn State (is_my_turn, turn_started, etc.)
├── AIInputCollector (existing, extend)
│   └── Queries AIBrain for decisions
│   └── Mode-aware (only queries in free mode or on turn)
├── ActionResolver (existing, can be shared)
│   └── Executes intents from AIBrain
│   └── Respects AP costs (combat mode)
└── HumanoidModel (existing)
    └── State machines respond to AIInputPackage
```

---

## 7. Implementation Strategy

### Phase 1: Basic AI (Free Movement)
- Simple state machine (IDLE → PATROL → IDLE)
- Basic movement to random points
- Simple object interaction
- **No combat yet** - just exploration behavior

### Phase 2: Combat AI (Turn-Based)
- Combat state detection
- Target nearest enemy
- Move to attack range
- Attack when in range
- Respect turn order (only act on NPC's turn)
- AP management

### Phase 3: Enhanced AI
- Multiple states (PATROL, INVESTIGATE, FLEE, COMBAT)
- Better target selection
- Cover/positioning
- Group coordination
- Dynamic priorities

### Phase 4: Advanced AI
- Behavior trees
- Learning/adaptation
- Complex multi-turn planning
- Tactical decision making

---

## 8. Key Design Decisions

### A. Use Existing Systems
- **Reuse `ActionResolver`**: NPCs use same system as player
- **Reuse `ActionIntent`**: Same intent types (MOVE, ATTACK, INTERACT, INVESTIGATE)
- **Reuse State Machines**: NPCs follow same state machine flow
- **Reuse Navigation**: Same NavigationAgent3D system

### B. Separation of Concerns
- **`AIBrain`**: Decision making (WHAT to do)
- **`ActionResolver`**: Execution (HOW to do it)
- **`AIInputCollector`**: Translation (convert decisions to input)
- **State Machines**: Animation/visual response

### C. Mode-Aware Design
- **Free Movement Mode**: AI acts every frame, no restrictions
- **Combat Mode**: AI only acts on its turn, respects AP
- **Mode Detection**: Check `GameManager.game_state`
- **Turn Detection**: Listen to `TurnController` signals

### D. Turn-Based Compatibility
- AI decisions happen at turn start (combat mode)
- Actions respect AP costs
- Can queue actions for next turn
- Between turns: AI is "frozen" (no new intents, but can react)

---

## 9. Example Flows

### Example 1: Free Movement Mode (Exploration)
```
Frame Update:
1. AIBrain.update(delta)
   - Game state: INVESTIGATION
   - Current state: PATROL
   - Check: Reached patrol point? → switch to IDLE
   
2. AIBrain.decide_action()
   - State: PATROL
   - Intent: MOVE to next patrol point
   
3. ActionResolver.set_intent(move_intent)
   - Navigate to patrol point
   
4. AIInputCollector.collect_input()
   - Reads ActionResolver state
   - If navigating → "walk"
   - If at destination → "idle"
   
5. State Machine responds
   - Plays walk/idle animations
```

### Example 2: Combat Mode - NPC's Turn
```
Turn Start:
1. TurnController.active_actor_changed → DustWalker
2. AIBrain.on_turn_start()
   - Game state: COMBAT
   - Evaluate: Health OK, enemy visible, AP available
   
3. AIBrain.decide_action()
   - State: COMBAT
   - Target: Nearest enemy (Player)
   - Intent: ATTACK
   - Plan: Move to range → Attack
   
4. ActionResolver.set_intent(attack_intent)
   - Navigate to attack range
   - When in range → execute attack
   - AP spent → turn ends
   
5. AIInputCollector.collect_input()
   - Reads ActionResolver state
   - If navigating → "walk"/"run"
   - If attacking → "attack"
   
6. State Machine responds
   - Plays appropriate animations
```

### Example 3: Combat Mode - Not NPC's Turn
```
Between Turns:
1. AIBrain.update(delta)
   - Game state: COMBAT
   - Check: is_my_turn? → NO
   - Action: Only update perception/memory
   - Do NOT generate new intents
   
2. AIInputCollector.collect_input()
   - Check: is_my_turn? → NO
   - Return: "idle" (or current state)
   - Exception: Can still trigger "hit" if damaged
   
3. State Machine
   - Maintains current state
   - Can play hit animation if damaged
   - No new actions
```

---

## 10. Benefits of This Architecture

- **Modular**: Swap AI brains without changing state machines
- **Reusable**: `ActionResolver` works for player and NPCs
- **Extensible**: Easy to add new behaviors/states
- **Testable**: Each component can be tested independently
- **Consistent**: NPCs use same systems as player
- **Mode-Aware**: Handles both free movement and turn-based combat
- **Performance**: AI only processes when needed (turn-based mode)

---

## 11. Technical Implementation Notes

### AIBrain Component Structure
```gdscript
class_name AIBrain
extends Node

enum AIMode { FREE_MOVEMENT, TURN_BASED }
enum AIState { IDLE, PATROL, INVESTIGATE, COMBAT, FLEE }

var current_mode: AIMode
var current_state: AIState
var is_my_turn: bool = false
var target: Actor = null
var memory: Dictionary = {}  # Blackboard for AI data

func _ready():
    # Connect to turn controller
    var tc = get_tree().get_first_node_in_group("turn_controller")
    if tc:
        tc.active_actor_changed.connect(_on_active_actor_changed)

func update(delta: float):
    current_mode = _get_current_mode()
    
    if current_mode == AIMode.TURN_BASED:
        if not is_my_turn:
            # Only update perception, no decisions
            _update_perception(delta)
            return
    
    # Free movement or my turn - make decisions
    _evaluate_situation()
    _decide_action()

func _get_current_mode() -> AIMode:
    if GameManager.game_state == GameManager.GameState.COMBAT:
        return AIMode.TURN_BASED
    return AIMode.FREE_MOVEMENT

func _on_active_actor_changed(actor: Actor):
    is_my_turn = (actor == get_parent())
    if is_my_turn:
        on_turn_start()
    else:
        on_turn_end()
```

### AIInputCollector Extension
```gdscript
func collect_input() -> AIInputPackage:
    var ai_input := AIInputPackage.new()
    
    # Check if in combat and not our turn
    if GameManager.game_state == GameManager.GameState.COMBAT:
        if not ai_brain.is_my_turn:
            # Between turns - only allow reactions (like hit)
            if _should_trigger_hit:
                ai_input.behaviour_names.append("hit")
                _should_trigger_hit = false
            else:
                ai_input.actions.append("idle")
            return ai_input
    
    # Free movement or our turn - get AI decision
    var intent = ai_brain.get_current_intent()
    if intent:
        # Convert intent to behaviour_names
        match intent.intent_type:
            ActionIntent.IntentType.ATTACK:
                ai_input.behaviour_names.append("attack")
            ActionIntent.IntentType.MOVE:
                ai_input.behaviour_names.append("walk")  # or "run"
            ActionIntent.IntentType.INTERACT:
                ai_input.behaviour_names.append("interact")
    
    # Handle damage reactions
    if _should_trigger_hit:
        ai_input.behaviour_names.append("hit")
        _should_trigger_hit = false
    
    return ai_input
```

---

## 12. Future Enhancements

- **Behavior Trees**: More complex decision making
- **Utility AI**: Score-based action selection
- **Group AI**: Coordinated group behaviors
- **Dynamic Difficulty**: AI adapts to player skill
- **Personality System**: Different AI personalities (aggressive, cautious, etc.)
- **Memory System**: NPCs remember past interactions
- **Learning**: NPCs adapt strategies over time

---

## Summary

This architecture provides a flexible, modular AI system that:
- Works in both free movement and turn-based combat modes
- Reuses existing systems (ActionResolver, state machines)
- Separates concerns (decision → execution → animation)
- Is easily extensible and testable
- Maintains consistency with player systems

The key insight is that NPCs should behave like players in free movement mode, but respect turn order in combat mode. The AI brain makes this distinction and adjusts its behavior accordingly.

