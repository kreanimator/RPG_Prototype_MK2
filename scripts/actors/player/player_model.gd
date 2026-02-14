extends Node
class_name PlayerModel

@export var stats_manager: StatsManager

@onready var combat: HumanoidCombat = $Combat
@onready var skeleton: Skeleton3D = %GeneralSkeleton
@onready var torso_machine: TorsoMachine = $Torso
@onready var legs_machine: LegsMachine = $Legs
@onready var area_awareness: AreaAwareness = $AreaAwareness
@onready var player_aim: PlayerAim = $PlayerAim
@onready var resources: PlayerResources = $Resources
@onready var action_resolver: ActionResolver = $ActionResolver
@onready var weapon_socket_ra: Node3D = $RightWrist/WeaponSocketRA
@onready var skeleton_animator: AnimationPlayer = $SkeletonAnimator
@onready var legs_anim_settings: AnimationPlayer = $LegsAnimationSettings

@onready var active_weapon: Weapon

var player: Player
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager
var current_behaviour: TorsoBehaviour

var _resources_initialized: bool = false


func _ready() -> void:
	player = get_parent() as Player

	# Wire references
	legs_machine.player = player
	legs_machine.forward_export_fields()

	torso_machine.player = player
	torso_machine.resources = resources
	torso_machine.accept_behaviours()

	player_aim.player = player


	current_behaviour = torso_machine.default_behaviour
	torso_machine.current_behaviour = current_behaviour
	current_behaviour._on_enter_behaviour(InputPackage.new())

	legs_anim_settings.play("simple")
	legs_machine.current_behaviour.on_enter_behaviour(InputPackage.new())


func update(input: InputPackage, delta: float) -> void:
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
	if player == null:
		return

	# Acquire managers when they exist
	if inventory_manager == null:
		inventory_manager = player.inventory_manager
	if equipment_manager == null:
		equipment_manager = player.equipment_manager

	# Only init when BOTH are ready (prevents em=<null> cases)
	if inventory_manager != null and equipment_manager != null:
		resources.model = self
		resources._init_stats(stats_manager, inventory_manager, equipment_manager)
		_resources_initialized = true

		# Recommended wiring for equipment manager (so current_weapon updates properly)
		if equipment_manager:
			equipment_manager.set_player_model(self)
			equipment_manager.set_stats_manager(stats_manager)
			equipment_manager.set_inventory_manager(inventory_manager)
