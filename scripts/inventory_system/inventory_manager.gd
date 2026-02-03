extends Node
class_name InventoryManager

# --- References ---
var stats_manager: StatsManager

# --- Inventory state (Array of ItemInstance) ---
var inventory: Array[ItemInstance] = []

# --- Signals ---
signal inventory_changed()  # Emitted when items are added/removed
signal item_added(item: ItemInstance, index: int)
signal item_removed(item: ItemInstance, index: int)
signal inventory_updated()  # Emitted when inventory is refreshed (e.g., from save)

#region ----- Item Catalog Loading -----
func get_items_catalog() -> Dictionary:
	return GameManager.get_items_catalog()

func get_item_base(catalog_id: String) -> Dictionary:
	return GameManager.get_item_base(catalog_id)
#endregion

#region ----- Inventory Operations -----
func add_item(catalog_id: String, qty: int = 1, overrides: Dictionary = {}) -> bool:
	var items_db = get_items_catalog()
	
	# Check if item exists in catalog
	if not items_db.has(catalog_id):
		push_error("Item with catalog_id '%s' not found in catalog" % catalog_id)
		return false
	
	var item_base = items_db[catalog_id]
	var item_weight: float = float(item_base.get("weight", 0.0))
	var total_weight: float = item_weight * qty
	
	# Check weight capacity
	if not _can_carry_weight(total_weight):
		print("Cannot add item: weight limit exceeded")
		return false
	
	# Check if item is stackable and if we can merge with existing stack
	if _is_stackable(catalog_id):
		for i in range(inventory.size()):
			var existing = inventory[i]
			if existing and existing.catalog_id == catalog_id:
				var temp_item = ItemInstance.new(catalog_id, qty, overrides)
				if existing.can_stack_with(temp_item, items_db):
					# Try to merge into existing stack
					var existing_max_stack = existing.max_stack(items_db)
					var space_left = existing_max_stack - existing.qty
					if space_left > 0:
						var to_add = min(qty, space_left)
						existing.qty += to_add
						_apply_weight(item_weight * to_add)
						inventory_changed.emit()
						item_added.emit(existing, i)
						
						# If there's remaining quantity, try to add more
						if qty > space_left:
							return add_item(catalog_id, qty - space_left, overrides)
						return true
	
	# Check inventory size limit
	if inventory.size() >= get_inventory_size():
		print("Cannot add item: inventory full")
		return false
	
	# Create new item instance with durability from catalog if not overridden
	var item_overrides = overrides.duplicate()
	if not item_overrides.has("durability"):
		var catalog_durability = item_base.get("durability", {})
		if catalog_durability is Dictionary and catalog_durability.has("max"):
			# Initialize durability from catalog (full durability)
			item_overrides["durability"] = {
				"cur": catalog_durability.get("max"),
				"max": catalog_durability.get("max")
			}
	
	# Check if we need to split the stack due to max_stack limit
	var max_stack = 1
	if _is_stackable(catalog_id):
		var temp_item = ItemInstance.new(catalog_id, 1, item_overrides)
		max_stack = temp_item.max_stack(items_db)
	
	# If quantity exceeds max_stack, split it
	if qty > max_stack and max_stack > 1:
		# Create a full stack and recursively add the remainder
		var full_stack_item = ItemInstance.new(catalog_id, max_stack, item_overrides)
		full_stack_item.bind_catalog(get_items_catalog())
		inventory.append(full_stack_item)
		_apply_weight(item_weight * max_stack)
		inventory_changed.emit()
		item_added.emit(full_stack_item, inventory.size() - 1)
		
		# Recursively add the remaining quantity
		return add_item(catalog_id, qty - max_stack, overrides)
	
	# Create new item instance with the quantity (within max_stack limit)
	var new_item = ItemInstance.new(catalog_id, qty, item_overrides)
	new_item.bind_catalog(get_items_catalog())
	
	# Add to inventory
	inventory.append(new_item)
	_apply_weight(total_weight)
	
	inventory_changed.emit()
	item_added.emit(new_item, inventory.size() - 1)
	return true

func remove_item(index: int, qty: int = -1) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	
	var item = inventory[index]
	if not item:
		return false
	
	var items_db = get_items_catalog()
	var item_base = items_db.get(item.catalog_id, {})
	var item_weight: float = float(item_base.get("weight", 0.0))
	
	# Remove specified quantity or entire item
	if qty <= 0 or qty >= item.qty:
		# Remove entire item
		_remove_weight(item_weight * item.qty)
		inventory.remove_at(index)
		inventory_changed.emit()
		item_removed.emit(item, index)
		return true
	else:
		# Remove partial quantity
		item.qty -= qty
		_remove_weight(item_weight * qty)
		inventory_changed.emit()
		item_removed.emit(item, index)
		return true

func remove_item_by_iid(iid: String, qty: int = -1) -> bool:
	for i in range(inventory.size()):
		var item = inventory[i]
		if item and item.iid == iid:
			return remove_item(i, qty)
	return false

func get_item(index: int) -> ItemInstance:
	if index >= 0 and index < inventory.size():
		return inventory[index]
	return null

func get_item_count() -> int:
	return inventory.size()

func get_total_weight() -> float:
	var total: float = 0.0
	var items_db = get_items_catalog()
	for item in inventory:
		if item:
			var item_base = items_db.get(item.catalog_id, {})
			var item_weight: float = float(item_base.get("weight", 0.0))
			total += item_weight * item.qty
	return total

func get_inventory_size() -> int:
	if stats_manager:
		var stats = stats_manager.get_stats()
		return int(stats.get("inventory_size", 20))
	return 20

func _is_stackable(catalog_id: String) -> bool:
	var items_db = get_items_catalog()
	var base = items_db.get(catalog_id, {})
	var max_stack: int = int((base.get("stack", {}) as Dictionary).get("max", 1))
	return max_stack > 1
#endregion

#region ----- Weight Management -----
func _can_carry_weight(weight: float) -> bool:
	if not stats_manager:
		return false
	var stats = stats_manager.get_stats()
	var current_weight = float(stats.get("current_weight", 0.0))
	var max_weight = float(stats.get("max_weight", 70.0))
	return (current_weight + weight) <= max_weight

func _apply_weight(weight: float) -> void:
	if stats_manager:
		var stats = stats_manager.get_stats()
		var current_weight = float(stats.get("current_weight", 0.0))
		stats["current_weight"] = current_weight + weight

func _remove_weight(weight: float) -> void:
	if stats_manager:
		var stats = stats_manager.get_stats()
		var current_weight = float(stats.get("current_weight", 0.0))
		stats["current_weight"] = max(0.0, current_weight - weight)
#endregion

#region ----- Serialization (for save/load) -----
func to_dict() -> Array:
	var result: Array = []
	for item in inventory:
		if item:
			result.append(item.to_dict())
	return result

func from_dict(data: Array) -> void:
	inventory.clear()
	_remove_weight(get_total_weight())  # Reset weight first
	
	print("[InventoryManager] Loading inventory from dict, items count: ", data.size())
	
	var items_db = get_items_catalog()
	for item_data in data:
		if item_data is Dictionary:
			var catalog_id = item_data.get("catalog_id", "")
			print("[InventoryManager] Loading item: ", catalog_id)
			
			# Initialize durability from catalog if not in save data
			if not item_data.has("durability"):
				var catalog_item = items_db.get(catalog_id, {})
				var catalog_durability = catalog_item.get("durability", {})
				if catalog_durability is Dictionary and catalog_durability.has("max"):
					# Initialize with max durability if not saved
					item_data["durability"] = {
						"cur": catalog_durability.get("max"),
						"max": catalog_durability.get("max")
					}
			
			var item = ItemInstance.from_dict(item_data)
			item.bind_catalog(items_db)
			inventory.append(item)
			
			# Recalculate weight
			var item_base = items_db.get(item.catalog_id, {})
			var item_weight: float = float(item_base.get("weight", 0.0))
			_apply_weight(item_weight * item.qty)
			print("[InventoryManager] Added item: %s (qty: %d)" % [item.get_name(items_db), item.qty])
	
	print("[InventoryManager] Finished loading. Total items: ", inventory.size())
	inventory_updated.emit()
#endregion

#region ----- Utility Methods -----
func set_stats_manager(sm: StatsManager) -> void:
	stats_manager = sm

func clear_inventory() -> void:
	_remove_weight(get_total_weight())
	inventory.clear()
	inventory_changed.emit()
#endregion
