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
	set_nav_agent()
	faction_component.faction = faction_component.Faction.PLAYER
	
func _physics_process(delta: float) -> void:
	var input = player_input.collect_input()
	player_model.update(input, delta)
	input.queue_free()
	_push_rigid_bodies()

func setup_visuals() -> void:
	player_visuals.accept_model(player_model)
	
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
