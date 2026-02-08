extends Node
class_name PlayerModel



#@export var interaction_manager: InteractionManager
@export var stats_manager: StatsManager
@onready var combat = $Combat as HumanoidCombat
@onready var skeleton = %GeneralSkeleton as Skeleton3D
@onready var torso_machine = $Torso as TorsoMachine
@onready var legs_machine = $Legs as LegsMachine
@onready var area_awareness = $AreaAwareness as AreaAwareness
@onready var player_aim = $PlayerAim as PlayerAim
@onready var resources = $Resources as PlayerResources
@onready var action_resolver = $ActionResolver as ActionResolver
@onready var active_weapon : Weapon
@onready var weapon_socket_ra: Node3D = $RightWrist/WeaponSocketRA
@onready var skeleton_animator: AnimationPlayer = $SkeletonAnimator

var player : Player
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager
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
	
	
func update(input : InputPackage, delta : float):
	# Update resources (stamina regeneration, etc.)
	#resources.update(delta)
	
	# Ensure equipment_manager is set (in case it wasn't ready in _ready())
	if not equipment_manager and player:
		equipment_manager = player.equipment_manager
	if not inventory_manager and player:
		inventory_manager = player.inventory_manager
	
	## Handle weapon slot switching
	#if input.actions.has("switch_weapon_slot_1"):
		#if equipment_manager:
			#print("Switching to WEAPON_1 slot")
			#equipment_manager.switch_weapon_slot("WEAPON_1")
		#else:
			#print("ERROR: equipment_manager is null when trying to switch to WEAPON_1")
	#if input.actions.has("switch_weapon_slot_2"):
		#if equipment_manager:
			#print("Switching to WEAPON_2 slot")
			#equipment_manager.switch_weapon_slot("WEAPON_2")
		#else:
			#print("ERROR: equipment_manager is null when trying to switch to WEAPON_2")
	#
	#player_aim.update_twinstick(input)
	combat.contextualize(input)
	area_awareness.contextualize(input)
	#interaction_manager.contextualize(input)
	
	# Update action resolver
	if action_resolver:
		action_resolver.update(delta)
	## Get active weapon from equipment manager if available, otherwise from socket
	#if equipment_manager and equipment_manager.current_weapon and is_instance_valid(equipment_manager.current_weapon):
		#active_weapon = equipment_manager.current_weapon
	#else:
		#active_weapon = get_weapon_from_socket(weapon_socket_ra)
	
	#prints(input.actions, input.aim_actions, input.combat_actions)
	var transition_verdict = current_behaviour.check_relevance(input)
	if transition_verdict != "okay":
		print(current_behaviour.behaviour_name + " -> " + transition_verdict)
		current_behaviour._on_exit_behaviour()
		current_behaviour = torso_machine.get_behaviour_by_name(transition_verdict)
		torso_machine.current_behaviour = current_behaviour
		current_behaviour._on_enter_behaviour(input)
	current_behaviour._update(input, delta)
