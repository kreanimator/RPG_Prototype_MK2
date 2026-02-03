extends RefCounted
class_name ItemInstance

# --- Identity / quantity ---
var catalog_id: String
var iid: String = ""         # UUID string (Utilities.generate_uuid())
var qty: int = 1

# --- Per-instance state (only what can change at runtime) ---
var durability := {"cur": null, "max": null}
var ammo: int = -1
var mods: Dictionary = {}
var meta: Dictionary = {}

# --- Cache of the catalog entry for fast UI lookups (not serialized) ---
var _base: Dictionary = {}

func _init(_catalog_id: String, _qty: int = 1, _overrides: Dictionary = {}):
	catalog_id = _catalog_id
	qty = max(1, _qty)
	iid = String(_overrides.get("iid", Utils.generate_uuid()))
	if _overrides.has("durability"): 
		var dur = _overrides.durability
		# Convert from JSON (floats) to ints
		if dur is Dictionary:
			var cur_val = dur.get("cur")
			var max_val = dur.get("max")
			durability = {}
			if cur_val != null:
				durability["cur"] = int(cur_val)
			else:
				durability["cur"] = null
			if max_val != null:
				durability["max"] = int(max_val)
			else:
				durability["max"] = null
		else:
			durability = dur
	if _overrides.has("ammo"):        
		var ammo_val = _overrides.ammo
		ammo = int(ammo_val) if ammo_val is float or ammo_val is int else -1
	if _overrides.has("mods"):        mods = _overrides.mods
	if _overrides.has("meta"):        meta = _overrides.meta

func to_dict() -> Dictionary:
	var d = {
		"iid": iid,
		"catalog_id": catalog_id,
		"qty": qty,
	}
	if durability.get("max") != null: d["durability"] = durability
	if ammo >= 0:                      d["ammo"] = ammo
	if not mods.is_empty():            d["mods"] = mods
	if not meta.is_empty():            d["meta"] = meta
	return d

static func from_dict(d: Dictionary) -> ItemInstance:
	return ItemInstance.new(d.get("catalog_id"), int(d.get("qty")), d)

#region ----- Catalog access helpers (work with a plain Dictionary catalog) -----
func _get_base(items_db: Dictionary) -> Dictionary:
	# Prefer bound _base snapshot if present; else read from items_db
	return (_base if not _base.is_empty() else items_db.get(catalog_id, {})) as Dictionary

func bind_catalog(items_db: Dictionary) -> void:
	# Optional: call this once after creating the instance to cache base data for UI
	_base = items_db.get(catalog_id, {}) as Dictionary
#endregion

#region ----- Lazy getters for UI (NO duplication in save files) -----
func get_name(items_db: Dictionary) -> String:
	return _get_base(items_db).get("name", "Unknown")

func get_desc(items_db: Dictionary) -> String:
	return _get_base(items_db).get("desc", "")

func get_icon_path(items_db: Dictionary) -> String:
	return _get_base(items_db).get("icon", "res://assets/inventory_icons/default.png")

func get_model_path(items_db: Dictionary) -> String:
	return _get_base(items_db).get("model", "")

func get_rarity(items_db: Dictionary) -> String:
	return _get_base(items_db).get("rarity", "COMMON")

func get_weight(items_db: Dictionary) -> float:
	return float(_get_base(items_db).get("weight", 0.0))

func get_value(items_db: Dictionary) -> int:
	return int(_get_base(items_db).get("value", 0))
#endregion

#region ----- Stacking-----
func is_stackable(items_db: Dictionary) -> bool:
	var base := _get_base(items_db)
	var maximum_stack: int = int((base.get("stack", {}) as Dictionary).get("max", 1))
	return maximum_stack > 1

func max_stack(items_db: Dictionary) -> int:
	var base := _get_base(items_db)
	return int((base.get("stack", {}) as Dictionary).get("max", 1))

func can_stack_with(other: ItemInstance, items_db: Dictionary) -> bool:
	if catalog_id != other.catalog_id:
		return false
	if not is_stackable(items_db) or not other.is_stackable(items_db):
		return false
	# Require identical per-instance state to merge
	return durability == other.durability \
		and ammo == other.ammo \
		and mods == other.mods \
		and meta == other.meta
#endregion
