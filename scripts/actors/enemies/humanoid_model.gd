extends Node
class_name HumanoidModel

@export var stats_manager: StatsManager

@onready var combat: HumanoidCombat = $Combat
@onready var skeleton: Skeleton3D = %GeneralSkeleton
@onready var torso_machine: TorsoMachineNPC = $Torso
@onready var legs_machine: LegsMachineNPC = $Legs
@onready var area_awareness: AreaAwareness = $AreaAwareness
@onready var resources: ActorResources = $Resources
@onready var action_resolver: ActionResolver = $ActionResolver
@onready var weapon_socket_ra: Node3D = $RightWrist/WeaponSocketRA
@onready var skeleton_animator: AnimationPlayer = $SkeletonAnimator
@onready var legs_anim_settings: AnimationPlayer = $LegsAnimationSettings

@onready var active_weapon: Weapon

var actor: Actor
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager
var current_behaviour: TorsoBehaviourNPC

# Move mode for this humanoid (can be changed dynamically by AI)
# Uses Actor.ActorMoveMode enum (not GameManager.MoveMode which is player-specific)
var move_mode: int = Actor.ActorMoveMode.WALK

var _resources_initialized: bool = false


func _ready() -> void:
	actor = get_parent() as Actor
	
	# Store reference in actor for state machine access
	# This allows legs actions to access actor.humanoid_model.resources
	# (similar to how Player has player_model)
	if actor.has_method("set_humanoid_model"):
		actor.set_humanoid_model(self)
	else:
		# Fallback: add property directly if method doesn't exist
		actor.set_meta("humanoid_model", self)

	# Wire references for NPC state machines
	if legs_machine:
		legs_machine.actor = actor
		legs_machine.forward_export_fields()

	if torso_machine:
		torso_machine.actor = actor
		torso_machine.resources = resources
		torso_machine.accept_behaviours()

	current_behaviour = torso_machine.default_behaviour
	torso_machine.current_behaviour = current_behaviour
	current_behaviour._on_enter_behaviour(AIInputPackage.new())

	if legs_anim_settings:
		legs_anim_settings.play("simple")
	if legs_machine and legs_machine.current_behaviour:
		legs_machine.current_behaviour.on_enter_behaviour(AIInputPackage.new())
	
	# Initialize ActionResolver with actor and model references
	if action_resolver:
		action_resolver.set_actor(actor)
		action_resolver.set_model(self)


func update(input: AIInputPackage, delta: float) -> void:
	# Ensure resources are initialized exactly once (safe, no repeated from_dict)
	_init_resources()

	# Update resources (AP regen etc.)
	resources.update(delta)

	# Context
	combat.contextualize(input)
	area_awareness.contextualize(input)

	# Resolver
	action_resolver.update(delta)

	# Behaviour transitions
	var transition_verdict := current_behaviour.check_relevance(input)
	if transition_verdict != "okay":
		current_behaviour._on_exit_behaviour()
		current_behaviour = torso_machine.get_behaviour_by_name(transition_verdict)
		torso_machine.current_behaviour = current_behaviour
		current_behaviour._on_enter_behaviour(input)

	current_behaviour._update(input, delta)


func _init_resources() -> void:
	if _resources_initialized:
		return
	if actor == null:
		return
	
	# For humanoids, resources are initialized directly in the actor's _ready()
	# (see enemy.gd - resources.initialize_humanoid_stats())
	# ActorResources is generic and works for all humanoids (enemies, NPCs, allies, etc.)
	# Only PlayerResources extends ActorResources with player-specific features (inventory, equipment)
	if resources:
		# Set actor reference if not already set
		if resources.actor == null:
			resources.set_actor(actor)
		
		# Resources are initialized using initialize_humanoid_stats() in the actor's _ready()
		# No special initialization needed here - just ensure actor reference is set
		_resources_initialized = true
		
		# Note: If a humanoid needs inventory/equipment managers (future feature),
		# they would use PlayerResources or a custom extension, not ActorResources

func set_move_mode(new_mode: int) -> void:
	"""Set the move mode for this humanoid (WALK, RUN, or CROUCH).
	Can be called by AI scripts to change movement behavior dynamically.
	Uses Actor.ActorMoveMode enum.
	Example: model.set_move_mode(Actor.ActorMoveMode.RUN) to make enemy chase faster."""
	move_mode = new_mode
	# Update ActionResolver's cached move_mode if it exists
	if action_resolver:
		action_resolver.move_mode = move_mode

func get_move_mode() -> int:
	"""Get the current move mode for this humanoid."""
	return move_mode
