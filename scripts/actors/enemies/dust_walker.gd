extends Actor
class_name DustWalker

# Stats (can be set in editor or via script)
@export var dust_walker_level: int = 1
@export var dust_walker_strength: int = 4
@export var dust_walker_perception: int = 5
@export var dust_walker_endurance: int = 4
@export var dust_walker_charisma: int = 2
@export var dust_walker_intelligence: int = 3
@export var dust_walker_agility: int = 5
@export var dust_walker_luck: int = 3
@export var dust_walker_health: float = 80.0
@export var dust_walker_max_health: float = 80.0
@export var dust_walker_max_action_points: int = 10
@export var dust_walker_armor: int = 2

@onready var dust_walker_model: HumanoidModel = $DustWalkerModel
@onready var enemy_visuals: HumanoidVisuals = $Visuals
@onready var resources: ActorResources = $Resources

func _ready() -> void:
	super._ready()
	
	# Initialize resources first
	if resources:
		resources.set_actor(self)
		resources.initialize_humanoid_stats(
			dust_walker_strength,
			dust_walker_perception,
			dust_walker_endurance,
			dust_walker_charisma,
			dust_walker_intelligence,
			dust_walker_agility,
			dust_walker_luck,
			dust_walker_health,
			dust_walker_max_health,
			dust_walker_level,
			dust_walker_max_action_points,
			dust_walker_armor
		)
	setup_visuals()
	setup_model()
	setup_inventory()
	set_nav_agent()
	faction_component.faction = faction_component.Faction.MUTANTS

func setup_visuals() -> void:
	if enemy_visuals and dust_walker_model:
		enemy_visuals.accept_model(dust_walker_model)

func setup_model() -> void:
	# Model setup is handled in HumanoidModel._ready()
	# Just ensure it's initialized
	pass

func setup_inventory() -> void:
	# For now, enemies don't have inventory/equipment managers
	# This can be added later if needed
	pass
