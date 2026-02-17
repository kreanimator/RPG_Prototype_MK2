extends ActorResources
class_name EnemyResources

# Enemy-specific resources
# For now, enemies have simpler stats than players

func _ready() -> void:
	super._ready()


## Initialize enemy stats with full stat initialization
## This calls the base initialize_stats() with all parameters
func initialize_enemy_stats(
		strength_value: int = 3,
		perception_value: int = 3,
		endurance_value: int = 3,
		charisma_value: int = 3,
		intelligence_value: int = 3,
		agility_value: int = 3,
		luck_value: int = 3,
		health_value: float = 100.0,
		max_health_value: float = 100.0,
		level_value: int = 1,
		max_action_points_value: int = 10,
		armor_value: int = 0
	) -> void:
	# Call base initialization with all stats
	initialize_stats(
		level_value,
		0,  # experience
		1000,  # max_experience
		health_value,
		max_health_value,
		0.0,  # hp_regeneration
		0,  # action_points (will be restored on turn start)
		max_action_points_value,
		armor_value,
		strength_value,
		perception_value,
		endurance_value,
		charisma_value,
		intelligence_value,
		agility_value,
		luck_value,
		1.0,  # sequence_multiplier
		[]  # statuses
	)


func recompute_derived_stats() -> void:
	super.recompute_derived_stats()
	# Enemy-specific derived stats can go here
