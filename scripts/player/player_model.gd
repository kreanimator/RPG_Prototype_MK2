extends Node
class_name PlayerModel


@export var player : Player
#@export var interaction_manager: InteractionManager
@export var stats_manager: StatsManager
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager

@onready var combat = $Combat as HumanoidCombat
@onready var skeleton = %GeneralSkeleton as Skeleton3D
@onready var torso_machine = $Torso as TorsoMachine
@onready var legs_machine = $Legs as LegsMachine
@onready var area_awareness = $AreaAwareness as AreaAwareness
@onready var player_aim = $PlayerAim as PlayerAim
@onready var resources = $Resources as PlayerResources
@onready var active_weapon : Weapon
@onready var weapon_socket_ra: Node3D = $RightWrist/WeaponSocketRA
#@onready var head_socket: Node3D = $Head/HelmetSocket

@onready var skeleton_animator: AnimationPlayer = $SkeletonAnimator

var current_behaviour : TorsoBehaviour

func _ready():
	player = get_parent()
	#area_awareness.player = player
	#area_awareness.player_RID = player.get_rid()
	legs_machine.player = player
	legs_machine.forward_export_fields()
	torso_machine.player = player
	torso_machine.resources = resources
	torso_machine.accept_behaviours()
	player_aim.player = player
	#camera_mount.player = player

	inventory_manager = player.inventory_manager
	equipment_manager = player.equipment_manager
	resources.model = self  # Set model reference for death triggering
	#resources._init_stats(stats_manager, inventory_manager, equipment_manager)
	
	if active_weapon:
		active_weapon.holder = self
	
	current_behaviour = torso_machine.default_behaviour
	torso_machine.current_behaviour = current_behaviour
	current_behaviour._on_enter_behaviour(InputPackage.new())
	$LegsAnimationSettings.play("simple")
	legs_machine.current_behaviour.on_enter_behaviour(InputPackage.new())
