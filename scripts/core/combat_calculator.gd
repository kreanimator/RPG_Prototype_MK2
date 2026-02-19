extends RefCounted
class_name CombatCalculator

# -------------------------
# Hit Chance Calculation (Fallout-style)
# -------------------------

## Get the skill name that corresponds to a weapon
## Returns skill name string or empty string if weapon is invalid
static func get_weapon_skill(weapon: Weapon) -> String:
	if weapon == null:
		return "unarmed"
	
	# Check if it's a ranged weapon
	if weapon is RangedWeapon:
		var ranged_weapon := weapon as RangedWeapon
		match ranged_weapon.ranged_subtype:
			RangedWeapon.RangedSubtype.PISTOL, \
			RangedWeapon.RangedSubtype.REVOLVER, \
			RangedWeapon.RangedSubtype.SHOTGUN, \
			RangedWeapon.RangedSubtype.RIFLE, \
			RangedWeapon.RangedSubtype.AUTO_RIFLE, \
			RangedWeapon.RangedSubtype.SNIPER_RIFLE:
				return "small_guns"
			RangedWeapon.RangedSubtype.HEAVY:
				return "big_guns"
		return "small_guns"  # Default for ranged
	
	# Check weapon range to determine if melee
	if weapon.weapon_range <= 0.0:
		# Melee weapon
		return "melee_weapons"
	
	# Default fallback
	return "unarmed"


## Calculate hit chance percentage (0-100) for an attack
## Formula: Base skill + modifiers - penalties
static func calculate_hit_chance(
	attacker: Actor,
	target: Actor,
	weapon: Weapon = null
) -> int:
	if attacker == null or target == null:
		return 0
	
	var attacker_resources := _get_actor_resources(attacker)
	if attacker_resources == null:
		return 0
	
	# Get relevant skill for the weapon
	var skill_name := get_weapon_skill(weapon)
	var base_skill := attacker_resources.get_skill(skill_name)
	
	# Start with base skill value
	var hit_chance := base_skill
	
	# Apply distance penalty for ranged weapons
	if weapon != null and weapon.weapon_range > 0.0:
		var distance := attacker.global_position.distance_to(target.global_position)
		var distance_penalty := _calculate_distance_penalty(distance, weapon.weapon_range)
		hit_chance -= distance_penalty
	
	# Apply target size modifier (larger targets easier to hit)
	# For now, assume all targets are medium size (no modifier)
	# Future: add size property to actors
	
	# Apply cover/obstacle penalties (future)
	# Future: raycast to check for cover
	
	# Clamp to valid range (0-100)
	return clamp(hit_chance, 0, 100)


## Calculate distance penalty for ranged weapons
## Penalty increases with distance beyond optimal range
static func _calculate_distance_penalty(distance: float, weapon_range: float) -> int:
	if weapon_range <= 0.0:
		return 0
	
	# Optimal range is 50% of weapon range
	var optimal_range := weapon_range * 0.5
	
	# No penalty within optimal range
	if distance <= optimal_range:
		return 0
	
	# Calculate penalty: 1% per meter beyond optimal range
	var excess_distance := distance - optimal_range
	var penalty := int(excess_distance)
	
	# Cap penalty at 50% (so even at max range, you have some chance)
	return min(penalty, 50)


## Roll for hit success
## Returns true if attack hits, false if it misses
## hit_chance: percentage chance (0-100)
static func roll_hit(hit_chance: int) -> bool:
	if hit_chance <= 0:
		return false
	if hit_chance >= 100:
		return true
	
	var roll := randi_range(1, 100)
	return roll <= hit_chance


## Calculate hit chance and roll for success in one call
## Returns dictionary with: { "hit": bool, "hit_chance": int, "roll": int }
static func calculate_and_roll_hit(
	attacker: Actor,
	target: Actor,
	weapon: Weapon = null
) -> Dictionary:
	var hit_chance := calculate_hit_chance(attacker, target, weapon)
	var roll := randi_range(1, 100)
	var hit := roll <= hit_chance
	
	return {
		"hit": hit,
		"hit_chance": hit_chance,
		"roll": roll
	}


## Get actor resources (handles both Player and generic Actor)
static func _get_actor_resources(actor: Actor) -> ActorResources:
	if actor is Player:
		var player := actor as Player
		return player.player_model.resources
	else:
		# For NPCs/enemies, resources are under the model (e.g., DustWalkerModel/Resources)
		# Check if actor has humanoid_model property
		if actor.humanoid_model != null:
			return actor.humanoid_model.resources
		# Fallback: try direct Resources node (for older setup or different actor types)
		return actor.get_node_or_null("Resources") as ActorResources

## Public accessor for getting actor resources (for use in other scripts)
static func get_actor_resources(actor: Actor) -> ActorResources:
	return _get_actor_resources(actor)
