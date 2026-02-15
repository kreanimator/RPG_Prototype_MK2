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

# --- Derived stat formulas (tweak freely) ---
const ARMOR_BASE_FLAT: int = 2          # naked baseline
const ARMOR_PER_END: float = 1.0
const ARMOR_PER_AGL: float = 0.5


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

# -------------------------
# Derived stats (Fallout-like)
# -------------------------

func get_level() -> int:
	return int(get_stats().get("level", 1))

func get_endurance() -> int:
	return int(get_stats().get("endurance", 1))

func get_strength() -> int:
	return int(get_stats().get("strength", 1))

func get_max_health() -> float:
	# Example formula (tweak to your balance):
	# Fallout-ish idea: base + END * X + level * Y
	var lvl := get_level()
	var endu := get_endurance()
	return float(20 + endu * 5 + lvl * 2)

func get_max_weight() -> float:
	# Example formula:
	# base + STR * X
	var str := get_strength()
	return float(50 + str * 8)

func get_current_weight_runtime() -> float:
	# Always compute from inventory
	if inventory_manager:
		return float(inventory_manager.get_total_weight())
	return float(get_stats().get("current_weight", 0.0)) # fallback only

func get_max_action_points() -> int:
	var s := get_stats()
	var agl := int(s["agility"])
	# Simple Fallout-ish baseline. Tune later.
	# Example: 6 base + AGL*2 (AGL=3 -> 12 AP)
	return 6 + agl * 2

func get_ap_restore_on_enter_combat() -> bool:
	# placeholder if later you want different rules
	return true

func get_armor_value() -> int:
	var s := get_stats()

	# Base armor from stats
	var endu := int(s.get("endurance", 0))
	var agl := int(s.get("agility", 0))

	var base_armor := ARMOR_BASE_FLAT \
		+ int(round(endu * ARMOR_PER_END)) \
		+ int(round(agl * ARMOR_PER_AGL))

	# Gear armor (damage resistance)
	var gear_armor := _get_equipped_armor_dr()

	return max(0, base_armor + gear_armor)


func _get_equipped_armor_dr() -> int:
	if equipment_manager == null:
		return 0

	var items_db: Dictionary = GameManager.get_items_catalog()
	var total := 0
	var armor_slots := ["HEAD", "CHEST", "LEGS", "HANDS", "FEET"]

	for slot in armor_slots:
		var item: ItemInstance = equipment_manager.get_equipped_item(slot)
		if item == null:
			continue

		var base: Dictionary = items_db.get(item.catalog_id, {})
		if base.is_empty():
			continue

		var armor_data: Dictionary = base.get("armor", {})
		total += int(armor_data.get("dr", 0))

	return total

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
	if model and model.resources:
		model.resources.recompute_derived_stats()

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
