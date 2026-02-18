extends Actor
class_name DummyEnemy

@export var auto_end_delay_sec: float = 10.0
@export var debug_ai: bool = true

# Debug stats for testing - full initialization
@export var debug_level: int = 1
@export var debug_strength: int = 3
@export var debug_perception: int = 3
@export var debug_endurance: int = 3
@export var debug_charisma: int = 3
@export var debug_intelligence: int = 3
@export var debug_agility: int = 3
@export var debug_luck: int = 3
@export var debug_health: float = 100.0
@export var debug_max_health: float = 100.0
@export var debug_max_action_points: int = 10
@export var debug_armor: int = 0

@onready var resources: ActorResources = $Resources

var _tc_ref: TurnController = null
var _auto_end_token: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	super._ready()
	
	# Initialize resources with full debug stats
	# Using generic ActorResources for all humanoids (enemies, NPCs, etc.)
	if resources:
		resources.set_actor(self)
		resources.initialize_humanoid_stats(
			debug_strength,
			debug_perception,
			debug_endurance,
			debug_charisma,
			debug_intelligence,
			debug_agility,
			debug_luck,
			debug_health,
			debug_max_health,
			debug_level,
			debug_max_action_points,
			debug_armor
		)


func on_turn_started(tc: Node) -> void:
	_tc_ref = tc as TurnController

	_auto_end_token += 1
	var token := _auto_end_token

	if debug_ai:
		print("[DummyEnemy] on_turn_started -> will finish action in ", auto_end_delay_sec, "s")

	await get_tree().create_timer(auto_end_delay_sec).timeout

	# cancelled / restarted
	if token != _auto_end_token:
		return

	# only if still valid + still its action slot
	if GameManager.game_state != GameManager.GameState.COMBAT:
		return
	if _tc_ref == null or not is_instance_valid(_tc_ref):
		return
	if _tc_ref.current_actor != self:
		return

	if debug_ai:
		print("[DummyEnemy] auto-end -> finish_turn() (end my action slot)")

	finish_turn()

func on_turn_ended(_tc: Node) -> void:
	# cancel pending timer by invalidating token
	_auto_end_token += 1
	if debug_ai:
		print("[DummyEnemy] on_turn_ended")

func _physics_process(delta: float) -> void:
	# Apply gravity to the dummy enemy
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	move_and_slide()
