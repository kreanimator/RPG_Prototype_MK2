extends Weapon
class_name RangedWeapon

enum FireMode {
	SINGLE,    # One shot per press
	BURST,     # Fixed number of shots, then stops
	AUTO       # Continuous while held
}

enum RangedSubtype {
	PISTOL,
	REVOLVER,
	SHOTGUN,
	RIFLE,
	AUTO_RIFLE,
	SNIPER_RIFLE,
	HEAVY
}

# Ranged weapon properties (loaded from item data)
var ranged_subtype: RangedSubtype = RangedSubtype.PISTOL
var fire_rate: float = 0.5  # Time between shots (loaded from item data)
var ammo_type: String = ""  # Type of ammo required (loaded from item data)
var magazine_size: int = 0  # Ammo capacity (loaded from item data)
var reload_time: float = 2.0  # Time to reload (loaded from item data)

# Bullet spread properties (loaded from item data)
var base_spread: float = 0.5  # Starting spread amount
var max_spread: float = 5.0  # Maximum spread when holding fire
var spread_increase_rate: float = 0.15  # How fast spread increases per shot
var current_spread: float = 0.5  # Current spread amount
var last_spread_update_time: float = 0.0  # Time of last spread update
var spread_cooldown: float = 1.0  # Time before spread resets to base

# Automatic weapon randomization (for natural bullet ejection effect)
var barrel_randomization_enabled: bool = false  # Enable for automatic weapons
var barrel_position_randomness: float = 0.02  # Random offset from barrel position (in meters)
var barrel_timing_randomness: float = 0.01  # Random timing variation (in seconds)
var barrel_speed_randomness: float = 0.05  # Random speed variation (as multiplier, e.g., 0.05 = ±5%)

# Ranged weapon properties (scene-specific, can be set in editor)
@export_group("Ranged Weapon")
@export var bullet_scene : PackedScene  # Scene for bullet/projectile
@export var shooting_point : Node3D  # Node3D child that represents where bullets spawn
@export var bullet_speed : float = 30.0

@export_group("Fire Mode")
@export var fire_mode: FireMode = FireMode.AUTO
var burst_size: int = 3  # For burst mode - number of shots per burst (loaded from item data)
var burst_delay: float = 0.1  # Time between bullets in a burst (loaded from item data)
@export var burst_cooldown: float = 0.5  # Time after burst before can shoot again

# Ranged weapon state
var current_ammo : int = 0
var last_shot_time : float = 0.0
var is_reloading : bool = false

# Burst state tracking
var shots_in_current_burst: int = 0
var last_burst_end_time: float = 0.0

# Ammo system - reference to the equipped ItemInstance and inventory manager
var item_instance: ItemInstance = null  # Reference to the equipped weapon item
var inventory_manager: InventoryManager = null  # Reference to inventory for ammo consumption

func _ready():
	super._ready()
	# For ranged weapons, disable Area3D collision entirely
	# They don't use Area3D for damage, bullets do
	monitoring = false
	monitorable = false
	
	# Initialize ammo - magazine_size should be loaded from item data before _ready()
	# If not set, use a default to prevent errors
	if magazine_size <= 0:
		push_warning("RangedWeapon._ready(): magazine_size is 0 or not set! Weapon may not work correctly. Ensure item data is loaded.")
		magazine_size = 1
	current_ammo = magazine_size

## Initialize ranged weapon from item data dictionary
func initialize_from_item_data(item_base: Dictionary) -> void:
	# Load common weapon properties (damage)
	super.initialize_from_item_data(item_base)
	
	var weapon_data = item_base.get("weapon", {})
	if not weapon_data is Dictionary:
		return
	
	# Load fire_rate (time between shots in seconds)
	if weapon_data.has("fire_rate"):
		fire_rate = float(weapon_data.get("fire_rate", 0.5))
	else:
		# Fallback: calculate from speed if fire_rate not present
		# speed is typically a multiplier, so we can derive fire_rate
		var speed = float(weapon_data.get("speed", 1.0))
		fire_rate = 0.5 / speed  # Base 0.5s divided by speed multiplier
	
	# Load magazine_size
	magazine_size = int(weapon_data.get("magazine_size", 0))
	current_ammo = magazine_size
	
	# Load reload_time
	reload_time = float(weapon_data.get("reload_time", 2.0))
	
	# Load ammo_type
	ammo_type = str(weapon_data.get("ammo_type", ""))
	
	# Load ranged subtype
	var subtype_str = str(weapon_data.get("subtype", "PISTOL"))
	match subtype_str:
		"PISTOL":
			ranged_subtype = RangedSubtype.PISTOL
		"REVOLVER":
			ranged_subtype = RangedSubtype.REVOLVER
		"SHOTGUN":
			ranged_subtype = RangedSubtype.SHOTGUN
		"RIFLE":
			ranged_subtype = RangedSubtype.RIFLE
		"AUTO_RIFLE":
			ranged_subtype = RangedSubtype.AUTO_RIFLE
		"SNIPER_RIFLE":
			ranged_subtype = RangedSubtype.SNIPER_RIFLE
		"HEAVY":
			ranged_subtype = RangedSubtype.HEAVY
		_:
			ranged_subtype = RangedSubtype.PISTOL
	
	# Load bullet spread settings
	var spread_data = weapon_data.get("spread", {})
	if spread_data is Dictionary:
		base_spread = float(spread_data.get("base", 0.5))
		max_spread = float(spread_data.get("max", 5.0))
		spread_increase_rate = float(spread_data.get("increase_rate", 0.15))
		current_spread = base_spread  # Initialize to base spread
	
	# Load fire mode and burst settings
	var fire_mode_str = str(weapon_data.get("fire_mode", "AUTO")).to_upper()
	match fire_mode_str:
		"SINGLE":
			fire_mode = FireMode.SINGLE
		"BURST":
			fire_mode = FireMode.BURST
		"AUTO":
			fire_mode = FireMode.AUTO
		_:
			fire_mode = FireMode.AUTO
	
	# Load burst settings
	if fire_mode == FireMode.BURST:
		burst_size = int(weapon_data.get("burst_size", 3))
		burst_delay = float(weapon_data.get("burst_delay", 0.1))
	
	# Enable barrel randomization for automatic weapons (AUTO fire mode or AUTO_RIFLE subtype)
	barrel_randomization_enabled = (fire_mode == FireMode.AUTO) or (ranged_subtype == RangedSubtype.AUTO_RIFLE)

## Set up ammo system with ItemInstance and InventoryManager
func setup_ammo_system(_item_instance: ItemInstance, _inventory_manager: InventoryManager) -> void:
	item_instance = _item_instance
	inventory_manager = _inventory_manager
	
	# Sync current_ammo with ItemInstance.ammo if it exists
	if item_instance and item_instance.ammo >= 0:
		current_ammo = item_instance.ammo
		# Clamp to magazine size
		current_ammo = min(current_ammo, magazine_size)
	else:
		# If no ammo stored, start with full magazine
		current_ammo = magazine_size
		_save_ammo_to_item()
	
	# Find shooting point if not set
	if not shooting_point:
		shooting_point = get_node_or_null("ShootingPoint") as Node3D

func shoot(target_direction: Vector3, target_position: Vector3 = Vector3.ZERO) -> bool:
	"""Shoot a bullet/projectile. Returns true if shot was successful."""
	if not can_shoot():
		return false
	
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_shot_time < fire_rate:
		return false
	
	if current_ammo <= 0:
		return false
	
	# Handle burst fire mode - fire all bullets in burst at once
	if fire_mode == FireMode.BURST:
		# Check if we're starting a new burst or continuing one
		if shots_in_current_burst == 0:
			# Start new burst - fire all bullets
			_fire_burst(target_direction, target_position)
			return true
		else:
			# Continue existing burst - fire single bullet
			# This handles action chaining for burst mode
			_fire_single_bullet(target_direction, target_position)
			return true
	
	# Single shot or auto mode - fire one bullet
	_fire_single_bullet(target_direction, target_position)
	return true

func _fire_burst(target_direction: Vector3, target_position: Vector3) -> void:
	"""Fire all bullets in a burst with delays between them (similar to Unity's BurstFire coroutine)"""
	for i in range(burst_size):
		if current_ammo <= 0:
			break
		
		# Fire bullet
		_fire_single_bullet(target_direction, target_position)
		
		# Wait before next bullet in burst (except for last one)
		if i < burst_size - 1:
			await get_tree().create_timer(burst_delay).timeout
			# Check again if we can continue (ammo might have changed)
			if current_ammo <= 0:
				break
	
	# Mark burst as complete
	var current_time = Time.get_unix_time_from_system()
	last_burst_end_time = current_time
	shots_in_current_burst = 0

func _fire_single_bullet(target_direction: Vector3, target_position: Vector3) -> void:
	"""Fire a single bullet (used by both single shot and burst mode)"""
	
	if not bullet_scene:
		push_error("RangedWeapon: No bullet_scene set for ranged weapon!")
		return
	
	var bullet = bullet_scene.instantiate() as BulletBase
	if not bullet:
		push_error("RangedWeapon: Failed to instantiate bullet!")
		return
	
	var scene = get_tree().current_scene
	if not scene:
		push_error("RangedWeapon: No current scene found!")
		return
	
	# Calculate base shoot position and direction
	var shoot_position: Vector3 = shooting_point.global_position if shooting_point else global_position
	var base_direction: Vector3 = (target_position - shoot_position).normalized() if target_position != Vector3.ZERO else target_direction.normalized()
	
	# Apply automatic weapon randomization (position, speed) for natural effect
	var final_bullet_speed: float = bullet_speed
	if barrel_randomization_enabled:
		# Add random position offset (simulates bullets not perfectly aligned in barrel)
		# Use shooting_point's local space for more natural offset
		if shooting_point:
			var local_offset = Vector3(
				randf_range(-barrel_position_randomness, barrel_position_randomness),
				randf_range(-barrel_position_randomness, barrel_position_randomness),
				randf_range(-barrel_position_randomness * 0.5, barrel_position_randomness * 0.5)  # Less forward/back variation
			)
			shoot_position = shooting_point.to_global(local_offset)
		else:
			# Fallback: random offset in world space
			shoot_position += Vector3(
				randf_range(-barrel_position_randomness, barrel_position_randomness),
				randf_range(-barrel_position_randomness, barrel_position_randomness),
				randf_range(-barrel_position_randomness, barrel_position_randomness)
			)
		
		# Add slight speed variation (simulates slight velocity differences between rounds)
		var speed_variation = randf_range(1.0 - barrel_speed_randomness, 1.0 + barrel_speed_randomness)
		final_bullet_speed = bullet_speed * speed_variation
		
		# Recalculate direction after position offset
		base_direction = (target_position - shoot_position).normalized() if target_position != Vector3.ZERO else target_direction.normalized()
	
	# Apply bullet spread to direction
	var direction: Vector3 = apply_bullet_spread(base_direction)
	
	# Add bullet to scene
	scene.add_child(bullet)
	
	# Initialize bullet with randomized properties
	bullet.initialize(shoot_position, direction, holder.player if holder else null, self)
	bullet.speed = final_bullet_speed
	bullet.damage = calculate_damage()
	bullet.call_deferred("_rotate_towards_direction", direction)
	
	# Consume ammo and update tracking
	current_ammo -= 1
	var current_time = Time.get_unix_time_from_system()
	last_shot_time = current_time
	_save_ammo_to_item()
	
	# Update bullet spread
	update_bullet_spread()
	
	# Update burst tracking
	if fire_mode == FireMode.BURST:
		shots_in_current_burst += 1
		if shots_in_current_burst >= burst_size:
			last_burst_end_time = current_time
			shots_in_current_burst = 0

func can_shoot() -> bool:
	"""Check if weapon can shoot (has ammo in magazine, not reloading, etc.)"""
	if is_reloading:
		return false
	
	# Can only shoot if we have ammo in magazine
	if current_ammo <= 0:
		return false
	
	# For burst mode, check if burst cooldown has passed
	if fire_mode == FireMode.BURST:
		var current_time = Time.get_unix_time_from_system()
		if shots_in_current_burst > 0:
			# In middle of burst, can continue
			return true
		elif last_burst_end_time > 0:
			# Check if cooldown has passed since last burst ended
			if current_time - last_burst_end_time < burst_cooldown:
				return false
	
	return true

func reload() -> void:
	"""Start reloading the weapon"""
	if is_reloading:
		return
	
	# Don't reload if magazine is already full
	if current_ammo >= magazine_size:
		return
	
	# For weapons with ammo system, check if we have matching ammo available in inventory
	if ammo_type != "" and inventory_manager:
		# Check if we have matching ammo type in inventory
		if not _has_ammo_in_inventory():
			return  # No matching ammo in inventory, can't reload
		
		# Don't reload if all available ammo is already in the magazine
		# (i.e., if magazine + inventory = total ammo, and magazine already has it all)
		var total_available_ammo = current_ammo + get_ammo_in_inventory()
		if total_available_ammo <= current_ammo:
			return  # No additional ammo to reload with
	else:
		# No ammo system (weapon doesn't use ammo from inventory), just fill magazine
		pass
	
	# Start reload timer
	is_reloading = true
	var reload_timer = Timer.new()
	add_child(reload_timer)
	reload_timer.wait_time = reload_time
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_finish_reload)
	reload_timer.start()

func _finish_reload() -> void:
	# Calculate how much ammo we need
	var ammo_needed = magazine_size - current_ammo
	if ammo_needed > 0 and ammo_type != "" and inventory_manager:
		# Try to consume ammo from inventory
		var ammo_consumed = _consume_ammo_from_inventory(ammo_needed)
		if ammo_consumed > 0:
			current_ammo += ammo_consumed
	else:
		# No ammo system or no ammo needed, just fill magazine
		current_ammo = magazine_size
	
	# Save ammo count to ItemInstance
	_save_ammo_to_item()
	is_reloading = false

func get_ammo_percentage() -> float:
	"""Get current ammo as percentage (0.0 to 1.0)"""
	if magazine_size <= 0:
		return 1.0
	
	return float(current_ammo) / float(magazine_size)

# FIXME: Aim line disabled - not pointing correctly to target, needs to be fixed later
func toggle_aim_line(_value: bool) -> void:
	"""Toggle aim line visibility. Override in subclasses to implement."""
	# Always keep aim line off until fixed
	pass

func reset_burst() -> void:
	"""Reset burst state (called when button is released or action ends)"""
	if fire_mode == FireMode.BURST and shots_in_current_burst > 0:
		# Record when burst ended if we had shots in progress
		last_burst_end_time = Time.get_unix_time_from_system()
	shots_in_current_burst = 0

## Consume ammo from inventory
## Returns the amount of ammo actually consumed
func _consume_ammo_from_inventory(amount: int) -> int:
	if not inventory_manager or ammo_type.is_empty():
		return 0
	
	# Find ammo items in inventory
	var ammo_consumed = 0
	var remaining = amount
	
	for i in range(inventory_manager.get_item_count()):
		var item = inventory_manager.get_item(i)
		if not item:
			continue
		
		# Check if this item matches our ammo type
		if item.catalog_id == ammo_type:
			var consume_from_stack = min(remaining, item.qty)
			if inventory_manager.remove_item(i, consume_from_stack):
				ammo_consumed += consume_from_stack
				remaining -= consume_from_stack
				
				if remaining <= 0:
					break
	
	return ammo_consumed


## Save current ammo count to ItemInstance
func _save_ammo_to_item() -> void:
	if item_instance:
		item_instance.ammo = current_ammo

## Check if there's ammo available in inventory
func _has_ammo_in_inventory() -> bool:
	return get_ammo_in_inventory() > 0

## Get total ammo count in inventory
func get_ammo_in_inventory() -> int:
	if not inventory_manager or ammo_type.is_empty():
		return 0
	
	var total_ammo = 0
	for i in range(inventory_manager.get_item_count()):
		var item = inventory_manager.get_item(i)
		if item and item.catalog_id == ammo_type:
			total_ammo += item.qty
	
	return total_ammo

## Apply bullet spread to direction (similar to Unity's ApplyBulletSpread)
func apply_bullet_spread(original_dir: Vector3) -> Vector3:
	update_bullet_spread()
	
	# Generate random spread value (same for all axes, matching Unity's implementation)
	var random_spread = randf_range(-current_spread, current_spread)
	
	# Create rotation using Euler angles with same random value for all axes
	# This matches Unity's: Quaternion.Euler(randomizedValue, randomizedValue, randomizedValue)
	var spread_rotation = Basis.from_euler(Vector3(
		deg_to_rad(random_spread),
		deg_to_rad(random_spread),
		deg_to_rad(random_spread)
	))
	
	# Apply rotation to direction
	return spread_rotation * original_dir

## Update bullet spread based on time since last shot (similar to Unity's UpdateBulletSpread)
func update_bullet_spread() -> void:
	var current_time = Time.get_unix_time_from_system()
	
	# If enough time has passed since last spread update, reset to base spread
	if current_time > last_spread_update_time + spread_cooldown:
		current_spread = base_spread
	else:
		# Otherwise, increase spread
		increase_spread()
	
	last_spread_update_time = current_time

## Increase spread by increase_rate, clamped to max_spread (similar to Unity's IncreaseSpread)
func increase_spread() -> void:
	current_spread = clamp(current_spread + spread_increase_rate, base_spread, max_spread)
