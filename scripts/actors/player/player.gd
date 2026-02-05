extends Actor
class_name Player

@export var camera_node: Node3D

@onready var player_input: InputCollector = $InputController
@onready var player_model: PlayerModel = $PlayerModel
@onready var player_visuals: PlayerVisuals = $PlayerVisuals
#@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var stats_manager: StatsManager = $StatsManager
@onready var equipment_manager: EquipmentManager = $EquipmentManager


func _ready() -> void:
	setup_visuals()
	set_nav_agent()
#### FIXME: Need to move movement logic to states, example:
#### pass nav agent and target position to state so state machine can use it

func _physics_process(delta: float) -> void:
	var input = player_input.collect_input()
	player_model.update(input, delta)
	input.queue_free()

func setup_visuals() -> void:
	player_visuals.accept_model(player_model)
