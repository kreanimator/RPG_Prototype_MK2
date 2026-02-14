extends Node
class_name StatsManager

enum CurrentUnarmedAction {PUNCH, KICK}

@export var is_input_debug_turned_on: bool = false

var model : PlayerModel
var stats = {}
var base_file_path : NodePath = "res://data/player/stats.json"
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager
var current_unarmed_action: CurrentUnarmedAction = CurrentUnarmedAction.PUNCH

#region Constants
const FATIGUE_TRESHOLD = 20
const WALK_SPEED : float = 3.5
const RUN_SPEED: float = 5.0
const SPRINT_SPEED: float = 7.0
#endregion

func _load_stats() -> Dictionary:
	var stats_data: Dictionary = File.load_json_file(base_file_path)
	return stats_data

func get_stats() -> Dictionary:
	# Lazy init the stats, for now it is very bad caching, so later we need some 
	# invalidation to have updated stats when we need them from here 
	if not stats:
		stats = _load_stats()
		# Load inventory from stats if inventory_manager is set
		# Note: This will be called again in set_inventory_manager if stats already exist
		if inventory_manager:
			_load_inventory_from_stats()
		# Load equipment from stats if equipment_manager is set
		if equipment_manager:
			_load_equipment_from_stats()
		return stats
	return stats

func set_model(mod: PlayerModel) -> void:
	model = mod

func set_inventory_manager(im: InventoryManager) -> void:
	inventory_manager = im
	# Ensure stats are loaded
	if not stats:
		stats = _load_stats()
	# Load inventory from stats
	_load_inventory_from_stats()

func set_equipment_manager(em: EquipmentManager) -> void:
	# Disconnect old signals if any
	if equipment_manager:
		if equipment_manager.equipment_changed.is_connected(_on_equipment_changed):
			equipment_manager.equipment_changed.disconnect(_on_equipment_changed)
	
	equipment_manager = em
	# Ensure stats are loaded
	if not stats:
		stats = _load_stats()
	# Load equipment from stats
	_load_equipment_from_stats()
	
	# Connect equipment changed signal to auto-save equipment to stats
	if equipment_manager:
		equipment_manager.equipment_changed.connect(_on_equipment_changed)

#region ----- Inventory Persistence -----
func _load_inventory_from_stats() -> void:
	if not inventory_manager or not stats:
		return
	
	var inventory_data = stats.get("inventory", [])
	if inventory_data is Array:
		inventory_manager.from_dict(inventory_data)
		print("Loaded ", inventory_manager.get_item_count(), " items from stats")

func save_inventory_to_stats() -> void:
	if not inventory_manager or not stats:
		return
	
	stats["inventory"] = inventory_manager.to_dict()
	# Also update current_weight to match inventory weight
	stats["current_weight"] = inventory_manager.get_total_weight()

func save_equipment_to_stats() -> void:
	if not equipment_manager or not stats:
		return
	
	stats["equipment"] = equipment_manager.to_dict()

func _load_equipment_from_stats() -> void:
	if not equipment_manager or not stats:
		return
	
	var equipment_data = stats.get("equipment", {})
	if equipment_data is Dictionary:
		equipment_manager.from_dict(equipment_data)
		print("Loaded equipment from stats")

func _on_equipment_changed() -> void:
	# Auto-save equipment to stats whenever equipment changes
	save_equipment_to_stats()

func get_unarmed_action_key() -> String:
	match current_unarmed_action:
		CurrentUnarmedAction.PUNCH:
			return "punch"
		CurrentUnarmedAction.KICK:
			return "kick"
	return "punch"
	
func get_unarmed_action_cost() -> int:
	match current_unarmed_action:
		CurrentUnarmedAction.PUNCH:
			return 3
		CurrentUnarmedAction.KICK:
			return 4
	return 1

func set_unarmed_action(action: CurrentUnarmedAction) -> void:
	current_unarmed_action = action

func save_stats_to_file() -> void:
	if not stats:
		return
	
	# Sync inventory before saving
	save_inventory_to_stats()
	# Sync equipment before saving
	save_equipment_to_stats()
	
	# Save to file
	File.write_json_file(base_file_path, stats)
	print("Stats saved to ", base_file_path)
#endregion
