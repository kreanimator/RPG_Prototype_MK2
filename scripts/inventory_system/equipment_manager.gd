extends Node
class_name EquipmentManager

const AVAILABLE_SLOTS = ["HEAD", "CHEST", "LEGS", "HANDS", "FEET", "WEAPON_1", "WEAPON_2", "TOOL_1", "TOOL_2", "CONSUMABLE"]
# --- References ---
var stats_manager: StatsManager
var inventory_manager: InventoryManager
var player_model: PlayerModel  # Reference to player model for weapon socket

var current_weapon: Weapon
var current_active_slot: String = "WEAPON_1"  # Currently active weapon slot
var weapon_instances: Dictionary = {}  # Dictionary of slot -> Weapon instance
var armor_instances: Dictionary = {}  # Dictionary of slot -> Node3D instance (armor scene)

# --- Equipment state (Dictionary of slot -> ItemInstance) ---
# Valid slots: "HEAD", "CHEST", "LEGS", "HANDS", "FEET", "WEAPON_1", "WEAPON_2"
var equipment: Dictionary = {}

# --- Signals ---
signal equipment_changed()
signal equipment_updated()  # Emitted when equipment is refreshed (e.g., from save)
signal weapon_equipped(slot: String, weapon: Weapon)
signal weapon_unequipped(slot: String)
signal active_slot_changed(slot: String)

#region ----- Equipment Operations -----
func equip_item(item: ItemInstance, slot: String) -> bool:
	if not item or not _is_valid_slot(slot):
		return false
	
	var items_db = GameManager.get_items_catalog()
	var item_base = items_db.get(item.catalog_id, {})
	var item_type = item_base.get("type", "")
	
	# Validate item type matches slot
	if slot in ["HEAD", "CHEST", "LEGS", "HANDS", "FEET"]:
		# Armor slots
		if item_type != "ARMOR":
			return false
		var armor_data = item_base.get("armor", {})
		if armor_data.get("slot", "") != slot:
			return false
	elif slot in ["WEAPON_1", "WEAPON_2"]:
		# Weapon slots - accept any weapon
		if item_type != "WEAPON":
			return false
	elif slot == "CONSUMABLE":
		# Consumable slot - accept any consumable
		if item_type != "CONSUMABLE":
			return false
	
	# Check requirements before equipping
	if not _check_requirements(item_base):
		return false
	
	# Unequip old item if exists
	var old_item = equipment.get(slot, null)
	if old_item:
		if inventory_manager and not inventory_manager.add_item(old_item.catalog_id, old_item.qty, old_item.to_dict()):
			return false  # Can't unequip old item, inventory full
		_remove_stat_modifiers(old_item)
		# Remove old weapon/armor instance
		if slot in ["WEAPON_1", "WEAPON_2"]:
			_unequip_weapon_scene(slot)
		elif slot in ["HEAD", "CHEST", "LEGS", "HANDS", "FEET"]:
			_unequip_armor_scene(slot)
	
	# Equip new item
	equipment[slot] = item
	_apply_stat_modifiers(item)
	
	# For weapons, instantiate and equip the weapon scene
	if slot in ["WEAPON_1", "WEAPON_2"]:
		if not _equip_weapon_scene(item, slot):
			# Failed to equip weapon scene, but item is still in equipment dict
			# This shouldn't happen, but handle gracefully
			equipment.erase(slot)
			_remove_stat_modifiers(item)
			return false
	# For armor, try to equip scene if available, otherwise equip virtually (stats only)
	elif slot in ["HEAD", "CHEST", "LEGS", "HANDS", "FEET"]:
		_equip_armor_scene(item, slot)  # This will handle virtual equipping if no scene
	# Consumables don't need scene equipping, just store in equipment dict
	
	equipment_changed.emit()
	return true

func unequip_item(slot: String, skip_validation: bool = false) -> ItemInstance:
	if not _is_valid_slot(slot):
		return null
	
	var item = equipment.get(slot, null)
	if not item:
		return null
	
	# Try to add to inventory
	if inventory_manager and not inventory_manager.add_item(item.catalog_id, item.qty, item.to_dict()):
		return null  # Inventory full
	
	# Remove weapon/armor scene if applicable
	if slot in ["WEAPON_1", "WEAPON_2"]:
		_unequip_weapon_scene(slot)
	elif slot in ["HEAD", "CHEST", "LEGS", "HANDS", "FEET"]:
		_unequip_armor_scene(slot)
	
	equipment.erase(slot)
	_remove_stat_modifiers(item)
	
	# After removing stat modifiers, validate all remaining equipped items
	# This ensures items that no longer meet requirements are unequipped
	# Skip validation if this is called from validation itself to avoid recursion
	if not skip_validation:
		_validate_all_equipped_items()
	
	equipment_changed.emit()
	return item

func get_equipped_item(slot: String) -> ItemInstance:
	return equipment.get(slot, null) if _is_valid_slot(slot) else null

func is_slot_equipped(slot: String) -> bool:
	return equipment.has(slot) and equipment[slot] != null
#endregion

#region ----- Slot Validation -----
func _is_valid_slot(slot: String) -> bool:
	return slot in AVAILABLE_SLOTS
#endregion

#region ----- Requirement Checking -----
func can_equip_item(item_base: Dictionary) -> bool:
	"""Public method to check if player meets item requirements. Returns true if requirements are met."""
	return _check_requirements(item_base)

func _check_requirements(item_base: Dictionary) -> bool:
	"""Check if player meets item requirements. Returns true if requirements are met."""
	if not stats_manager:
		return true  # No stats manager, allow equipping
	
	var requirements = item_base.get("requirements", {})
	if not requirements is Dictionary:
		return true  # No requirements, allow equipping
	
	var player_stats = stats_manager.get_stats()
	
	# Check level requirement
	var req_level = requirements.get("level", 0)
	if req_level > 0:
		var player_level = player_stats.get("level", 0)
		if player_level < req_level:
			return false  # Level requirement not met
	
	# Check stat requirements
	var req_stats = requirements.get("stats", {})
	if req_stats is Dictionary:
		var stat_mapping = {
			"STR": "strength",
			"AGL": "agility",
			"END": "endurance",
			"PER": "perception",
			"INT": "intelligence",
			"LCK": "luck",
			"CHA": "charisma"
		}
		
		for stat_abbr in req_stats:
			var req_value = req_stats[stat_abbr]
			var stat_key = stat_mapping.get(stat_abbr, stat_abbr.to_lower())
			var player_value = player_stats.get(stat_key, 0)
			if player_value < req_value:
				return false  # Stat requirement not met
	
	return true  # All requirements met

func _validate_all_equipped_items() -> void:
	"""Check all equipped items and unequip any that no longer meet requirements.
	This is called after unequipping an item to ensure remaining items are still valid.
	Uses a loop to handle dependency chains (e.g., weapon needs hat A, hat A needs hat B)."""
	if not stats_manager:
		return  # No stats manager, can't validate
	
	var items_db = GameManager.get_items_catalog()
	var max_iterations = 10  # Safety limit to prevent infinite loops
	var iteration = 0
	
	# Keep validating until no more items need to be unequipped
	# This handles chains of dependencies
	while iteration < max_iterations:
		iteration += 1
		var slots_to_unequip = []
		
		# First pass: identify items that don't meet requirements
		for slot in equipment.keys():
			var item = equipment.get(slot, null)
			if not item:
				continue
			
			var item_base = items_db.get(item.catalog_id, {})
			if item_base.is_empty():
				continue
			
			# Check if item still meets requirements
			if not _check_requirements(item_base):
				slots_to_unequip.append(slot)
		
		# If no items need to be unequipped, we're done
		if slots_to_unequip.is_empty():
			break
		
		# Second pass: unequip items that don't meet requirements
		# We do this in a separate pass to avoid modifying the dictionary while iterating
		# Use skip_validation=true to avoid recursive validation calls
		for slot in slots_to_unequip:
			unequip_item(slot, true)  # Skip validation to avoid recursion
#endregion

#region ----- Stat Modifiers -----
func _apply_stat_modifiers(item: ItemInstance) -> void:
	if not stats_manager or not item:
		return
	
	var items_db = GameManager.get_items_catalog()
	var item_base = items_db.get(item.catalog_id, {})
	var stat_modifiers: Dictionary = {}
	
	# Get stat modifiers from armor or weapon
	if item_base.get("type", "") == "ARMOR":
		stat_modifiers = item_base.get("armor", {}).get("stats", {})
	elif item_base.get("type", "") == "WEAPON":
		stat_modifiers = item_base.get("weapon", {}).get("stats", {})
	
	if stat_modifiers.is_empty():
		return
	
	var stats = stats_manager.get_stats()
	for stat_name in stat_modifiers:
		var modifier = stat_modifiers[stat_name]
		if modifier is int or modifier is float:
			stats[stat_name] = stats.get(stat_name, 0) + modifier

func _remove_stat_modifiers(item: ItemInstance) -> void:
	if not stats_manager or not item:
		return
	
	var items_db = GameManager.get_items_catalog()
	var item_base = items_db.get(item.catalog_id, {})
	var stat_modifiers: Dictionary = {}
	
	# Get stat modifiers from armor or weapon
	if item_base.get("type", "") == "ARMOR":
		stat_modifiers = item_base.get("armor", {}).get("stats", {})
	elif item_base.get("type", "") == "WEAPON":
		stat_modifiers = item_base.get("weapon", {}).get("stats", {})
	
	if stat_modifiers.is_empty():
		return
	
	var stats = stats_manager.get_stats()
	for stat_name in stat_modifiers:
		var modifier = stat_modifiers[stat_name]
		if modifier is int or modifier is float:
			stats[stat_name] = max(0, stats.get(stat_name, 0) - modifier)
#endregion

#region ----- Serialization -----
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for slot in equipment:
		if equipment[slot]:
			result[slot] = equipment[slot].to_dict()
	return result

func from_dict(data: Dictionary) -> void:
	# Clear current equipment and weapon/armor instances
	for slot in equipment.keys():
		_remove_stat_modifiers(equipment[slot])
		if slot in ["WEAPON_1", "WEAPON_2"]:
			_unequip_weapon_scene(slot)
		elif slot in ["HEAD", "CHEST", "LEGS", "HANDS", "FEET"]:
			_unequip_armor_scene(slot)
	equipment.clear()
	weapon_instances.clear()
	armor_instances.clear()
	
	var items_db = GameManager.get_items_catalog()
	for slot in data:
		if not _is_valid_slot(slot) or not data[slot] is Dictionary:
			continue
		
		var item_data = data[slot]
		# Initialize durability from catalog if needed
		if not item_data.has("durability"):
			var catalog_durability = items_db.get(item_data.get("catalog_id", ""), {}).get("durability", {})
			if catalog_durability is Dictionary and catalog_durability.has("max"):
				item_data["durability"] = {"cur": catalog_durability.get("max"), "max": catalog_durability.get("max")}
		
		var item = ItemInstance.from_dict(item_data)
		item.bind_catalog(items_db)
		equipment[slot] = item
		_apply_stat_modifiers(item)
		
		# Equip weapon/armor scenes for appropriate slots
		if slot in ["WEAPON_1", "WEAPON_2"]:
			_equip_weapon_scene(item, slot)
		elif slot in ["HEAD", "CHEST", "LEGS", "HANDS", "FEET"]:
			_equip_armor_scene(item, slot)
	
	# Switch to active slot after loading
	# If active slot has no weapon, try the other slot
	if not weapon_instances.has(current_active_slot) or weapon_instances[current_active_slot] == null:
		var other_slot = "WEAPON_2" if current_active_slot == "WEAPON_1" else "WEAPON_1"
		if weapon_instances.has(other_slot) and weapon_instances[other_slot] != null:
			current_active_slot = other_slot
	
	_switch_to_slot(current_active_slot)
	equipment_updated.emit()
#endregion

#region ----- Weapon Scene Management -----
func _equip_weapon_scene(item: ItemInstance, slot: String) -> bool:
	"""Instantiate and equip weapon scene for the given item and slot"""
	if not player_model:
		push_error("EquipmentManager: player_model not set, cannot equip weapon scene")
		return false
	
	var items_db = GameManager.get_items_catalog()
	var item_base = items_db.get(item.catalog_id, {})
	var weapon_scene_path = item_base.get("weapon_scene", "")
	
	if weapon_scene_path.is_empty():
		push_error("EquipmentManager: No weapon_scene path for item: " + item.catalog_id)
		return false
	
	# Load and instantiate weapon scene
	var weapon_scene = load(weapon_scene_path) as PackedScene
	if not weapon_scene:
		push_error("EquipmentManager: Failed to load weapon scene: " + weapon_scene_path)
		return false
	
	var weapon_instance = weapon_scene.instantiate() as Weapon
	if not weapon_instance:
		push_error("EquipmentManager: Failed to instantiate weapon from scene: " + weapon_scene_path)
		return false
	
	# Get weapon socket
	var weapon_socket = player_model.weapon_socket_ra
	if not weapon_socket:
		push_error("EquipmentManager: Weapon socket not found")
		weapon_instance.queue_free()
		return false
	
	# Initialize weapon from item data BEFORE adding to scene tree
	# This ensures _ready() has access to initialized stats
	weapon_instance.initialize_from_item_data(item_base)
	
	# Set weapon holder before adding to tree
	weapon_instance.holder = player_model
	
	# Set up ammo system for ranged weapons
	if weapon_instance is RangedWeapon:
		var ranged_weapon = weapon_instance as RangedWeapon
		ranged_weapon.setup_ammo_system(item, inventory_manager)
	
	# Add weapon to socket (this will trigger _ready())
	weapon_socket.add_child(weapon_instance)
	
	# Apply socket position and rotation from weapon scene
	weapon_instance.position = weapon_instance.socket_position
	weapon_instance.rotation = weapon_instance.socket_rotation
	
	# Store weapon instance
	weapon_instances[slot] = weapon_instance
	
	# Hide weapon if it's not the active slot
	if slot != current_active_slot:
		weapon_instance.visible = false
	
	# If this is the active slot, make it the active weapon
	if slot == current_active_slot:
		_switch_to_slot(slot)
	
	weapon_equipped.emit(slot, weapon_instance)
	return true

func _unequip_weapon_scene(slot: String) -> void:
	"""Remove weapon scene for the given slot"""
	if not weapon_instances.has(slot):
		return
	
	var weapon = weapon_instances[slot]
	if is_instance_valid(weapon):
		# If this is the active weapon, clear it BEFORE freeing
		if current_weapon == weapon or (player_model and player_model.active_weapon == weapon):
			current_weapon = null
			if player_model:
				player_model.active_weapon = null
		weapon.queue_free()
	
	weapon_instances.erase(slot)
	weapon_unequipped.emit(slot)

func switch_weapon_slot(slot: String) -> bool:
	"""Switch to the specified weapon slot (1 or 2)"""
	print("EquipmentManager.switch_weapon_slot called with slot: ", slot)
	if slot not in ["WEAPON_1", "WEAPON_2"]:
		print("ERROR: Invalid slot: ", slot)
		return false
	
	if slot == current_active_slot:
		print("Already on slot: ", slot)
		return true  # Already on this slot
	
	print("Switching from ", current_active_slot, " to ", slot)
	current_active_slot = slot
	_switch_to_slot(slot)
	active_slot_changed.emit(slot)
	return true

func _switch_to_slot(slot: String) -> void:
	"""Internal method to switch active weapon to the specified slot"""
	if not player_model:
		return
	
	# Hide all weapons first
	for weapon_slot in weapon_instances:
		var w = weapon_instances[weapon_slot]
		if is_instance_valid(w):
			w.visible = false
	
	# Get weapon from slot
	var weapon = weapon_instances.get(slot, null)
	
	# Update active weapon
	current_weapon = weapon
	player_model.active_weapon = weapon
	
	# Show active weapon if it exists
	if weapon and is_instance_valid(weapon):
		weapon.visible = true
	else:
		# If no weapon in slot, we're unarmed
		current_weapon = null
		player_model.active_weapon = null
#endregion

#region ----- Armor Scene Management -----
func _equip_armor_scene(item: ItemInstance, slot: String) -> bool:
	"""Instantiate and equip armor scene for the given item and slot. Returns true if scene was equipped, false if virtual equip (no scene)"""
	if not player_model:
		# No player model, but still allow virtual equipping (stats only)
		return false
	
	var items_db = GameManager.get_items_catalog()
	var item_base = items_db.get(item.catalog_id, {})
	var armor_scene_path = item_base.get("armor_scene", "")
	
	# If no armor_scene path, equip virtually (stats only, no visual)
	if armor_scene_path.is_empty():
		# Virtual equip - stats are already applied, just return
		return false
	
	# Load and instantiate armor scene
	var armor_scene = load(armor_scene_path) as PackedScene
	if not armor_scene:
		push_warning("EquipmentManager: Failed to load armor scene: " + armor_scene_path + " - equipping virtually")
		return false
	
	var armor_instance = armor_scene.instantiate() as Node3D
	if not armor_instance:
		push_warning("EquipmentManager: Failed to instantiate armor from scene: " + armor_scene_path + " - equipping virtually")
		return false
	
	# Get appropriate socket based on slot
	var armor_socket: Node3D = null
	match slot:
		"HEAD":
			armor_socket = player_model.head_socket if player_model else null
		# Add other slots (CHEST, LEGS, HANDS, FEET) as needed when sockets are added
		_:
			push_warning("EquipmentManager: No socket defined for armor slot: " + slot + " - equipping virtually")
			armor_instance.queue_free()
			return false
	
	if not armor_socket:
		push_warning("EquipmentManager: Armor socket not found for slot: " + slot + " - equipping virtually")
		armor_instance.queue_free()
		return false
	
	# Add armor to socket
	armor_socket.add_child(armor_instance)
	
	# Store armor instance
	armor_instances[slot] = armor_instance
	
	return true

func _unequip_armor_scene(slot: String) -> void:
	"""Remove armor scene for the given slot"""
	if not armor_instances.has(slot):
		return
	
	var armor = armor_instances[slot]
	if is_instance_valid(armor):
		armor.queue_free()
	
	armor_instances.erase(slot)
#endregion

#region ----- Utility Methods -----
func set_stats_manager(sm: StatsManager) -> void:
	stats_manager = sm

func set_inventory_manager(im: InventoryManager) -> void:
	inventory_manager = im

func set_player_model(pm: PlayerModel) -> void:
	player_model = pm
#endregion
