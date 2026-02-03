extends Area3D
class_name Weapon

enum WeaponType{
	UNARMED,
	MELEE_BLUNT,
	MELEE_SHARP,
	MELEE_TWO_HANDED,
	PISTOL,
	REVOLVER,
	SHOTHUN,
	AUTO_RIFLE,
	RIFLE,
	SNIPER_RIFLE
}

@export var holder : PlayerModel
@export var base_damage : float = 2  # Legacy, kept for backwards compatibility
var min_damage : float = 0  # Loaded from item data
var max_damage : float = 1  # Loaded from item data
@export var weapon_type: WeaponType = WeaponType.UNARMED

# Weapon socket placement (set in scene)
@export_group("Socket Placement")
@export var socket_position: Vector3 = Vector3.ZERO
@export var socket_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	pass

func get_hit_data() -> HitData:
	return HitData.blank()

## Initialize weapon from item data dictionary
## Override in subclasses to load weapon-specific properties
func initialize_from_item_data(item_base: Dictionary) -> void:
	var weapon_data = item_base.get("weapon", {})
	if not weapon_data is Dictionary:
		return
	
	# Load damage (common to all weapons)
	var damage_data = weapon_data.get("damage", {})
	if damage_data is Dictionary:
		min_damage = float(damage_data.get("min", 10))
		max_damage = float(damage_data.get("max", 10))
		# Also set base_damage for backwards compatibility (use average)
		base_damage = (min_damage + max_damage) / 2.0
	else:
		# Fallback if damage is not a dict
		min_damage = float(weapon_data.get("damage", 10))
		max_damage = min_damage
		base_damage = min_damage

## Calculate random damage between min_damage and max_damage (inclusive)
func calculate_damage() -> float:
	if min_damage <= 0 and max_damage <= 0:
		# Fallback to base_damage if min/max not set
		return base_damage
	# Use randf_range which includes both min and max in Godot 4
	# Round to integer since items.json uses integer damage values
	return float(randi_range(int(min_damage), int(max_damage)))
