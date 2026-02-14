extends Actor
class_name Player

#region Rigid Body Pushing Constants
const LIGHT_OBJECT_BOOST: float = 3.0
const MIN_MASS_RATIO: float = 0.1
#endregion

@export var camera_node: Node3D

@onready var player_input: InputCollector = $InputController
@onready var player_model: PlayerModel = $PlayerModel
#@onready var player_visuals: PlayerVisuals = $PlayerVisuals
#@onready var mouse_interactor: MouseInteractor = $MouseInteractor
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var stats_manager: StatsManager = $StatsManager
@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var player_visuals: PlayerVisuals = $PlayerVisuals


func _ready() -> void:
	setup_visuals()
	setup_model()
	setup_inventory()
	set_nav_agent()
	faction_component.faction = faction_component.Faction.PLAYER
	
func _physics_process(delta: float) -> void:
	var input = player_input.collect_input()
	player_model.update(input, delta)
	input.queue_free()
	_push_rigid_bodies()

func setup_model() -> void:
	stats_manager.set_model(player_model)

func setup_inventory() -> void:
	# Connect InventoryManager and StatsManager
	inventory_manager.set_stats_manager(stats_manager)
	stats_manager.set_inventory_manager(inventory_manager)
	
	# Connect EquipmentManager to StatsManager and InventoryManager
	equipment_manager.set_stats_manager(stats_manager)
	equipment_manager.set_inventory_manager(inventory_manager)
	equipment_manager.set_player_model(player_model)
	stats_manager.set_equipment_manager(equipment_manager)
	
	# Connect equipment signals
	equipment_manager.equipment_changed.connect(_on_equipment_changed)
	equipment_manager.weapon_equipped.connect(_on_weapon_equipped)
	equipment_manager.weapon_unequipped.connect(_on_weapon_unequipped)
	equipment_manager.active_slot_changed.connect(_on_active_slot_changed)
	
	## Connect InventoryUI to InventoryManager, EquipmentManager and StatsManager
	#if player_visuals and player_visuals.inventory:
		#player_visuals.inventory.set_inventory_manager(inventory_manager)
		#player_visuals.inventory.set_equipment_manager(equipment_manager)
		#player_visuals.inventory.set_stats_manager(stats_manager)
		#player_visuals.inventory.set_player_resources(player_model.resources)
		#print("Connected InventoryUI to InventoryManager, EquipmentManager and StatsManager")


func setup_visuals() -> void:
	player_visuals.accept_model(player_model)


func _on_equipment_changed() -> void:
	# Update active weapon when equipment changes
	if equipment_manager:
		equipment_manager._switch_to_slot(equipment_manager.current_active_slot)

func _on_weapon_equipped(slot: String, _weapon: Weapon) -> void:
	# Weapon was equipped, switch to it if it's the active slot
	if equipment_manager and slot == equipment_manager.current_active_slot:
		equipment_manager._switch_to_slot(slot)

func _on_weapon_unequipped(slot: String) -> void:
	# Weapon was unequipped, if it was active, switch to other slot or unarmed
	if equipment_manager and slot == equipment_manager.current_active_slot:
		# Try to switch to other slot
		var other_slot = "WEAPON_2" if slot == "WEAPON_1" else "WEAPON_1"
		if equipment_manager.is_slot_equipped(other_slot):
			equipment_manager.switch_weapon_slot(other_slot)
		else:
			# Both slots empty, go unarmed
			equipment_manager._switch_to_slot(slot)

func _on_active_slot_changed(slot: String) -> void:
	# Active slot changed, update active weapon
	if equipment_manager:
		equipment_manager._switch_to_slot(slot)


func _push_rigid_bodies():
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var rigid_body = c.get_collider()
			var knockback_dir = (rigid_body.global_position - global_position).normalized()
			knockback_dir.y = 0
			
			# Adding player mass to interaction
			#var player_mass = model.resources._get_player_mass()
			var player_mass = 60
			var mass_ratio = clamp(player_mass / rigid_body.mass, MIN_MASS_RATIO, 1.0)
			var knockback_force = 2.0 * mass_ratio
			
			rigid_body.apply_impulse(knockback_dir * knockback_force)
