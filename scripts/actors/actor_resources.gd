extends Node
class_name ActorResources

# -------------------------
# Signals
# -------------------------
signal action_points_changed(ap: int, max_ap: int)
signal out_of_ap()
signal health_changed(current: float, max: float)
signal died()
signal level_changed(new_level: int)
signal experience_gained(amount: int)

# -------------------------
# Core Stats (common to all actors)
# -------------------------
var level: int = 1
var experience: int = 0
var max_experience: int = 1000

# Health system
var health: float = 100.0
var max_health: float = 100.0
var hp_regeneration: float = 0.0

# Action Points system
var action_points: int = 0
var max_action_points: int = 10

# Status effects (using Array for now, can be optimized to Set if needed)
var statuses: Array[String] = []

# Armor/Damage Resistance
var armor: int = 0

# Sequence stat (turn order)
var sequence: int = 0

# Base stats (S.P.E.C.I.A.L. - Fallout-like)
var strength: int = 3
var perception: int = 3
var endurance: int = 3
var charisma: int = 3
var intelligence: int = 3
var agility: int = 3
var luck: int = 3

# Perk multipliers (for future use)
var sequence_multiplier: float = 1.0

# Skills system
# Base skill values (0-100%, can be modified by perks/equipment)
var skills_base: Dictionary = {
	"unarmed": 5,
	"melee_weapons": 5,
	"small_guns": 5,
	"big_guns": 5,
	"energy_weapons": 5,
	"throwing": 5,
}

# Calculated skill values (base + stat bonuses)
var skills: Dictionary = {}

# -------------------------
# Runtime references
# -------------------------
var actor: Actor = null  # Reference to the owning Actor
var is_invincible: bool = false

# -------------------------
# Initialization
# -------------------------
func _ready() -> void:
	pass


func update(_delta: float) -> void:
	# Override in subclasses for per-frame updates (e.g., HP regen)
	pass


## Initialize all stats for an actor
## Override in subclasses to add additional initialization
func initialize_stats(
		level_value: int = 1,
		experience_value: int = 0,
		max_experience_value: int = 1000,
		health_value: float = 100.0,
		max_health_value: float = 100.0,
		hp_regeneration_value: float = 0.0,
		action_points_value: int = 0,
		max_action_points_value: int = 10,
		armor_value: int = 0,
		strength_value: int = 3,
		perception_value: int = 3,
		endurance_value: int = 3,
		charisma_value: int = 3,
		intelligence_value: int = 3,
		agility_value: int = 3,
		luck_value: int = 3,
		sequence_multiplier_value: float = 1.0,
		statuses_array: Array[String] = []
	) -> void:
	# Core stats
	level = level_value
	experience = experience_value
	max_experience = max_experience_value
	
	# Health system
	health = health_value
	max_health = max_health_value
	hp_regeneration = hp_regeneration_value
	
	# Action Points
	action_points = action_points_value
	max_action_points = max_action_points_value
	
	# Armor
	armor = armor_value
	
	# Base stats (S.P.E.C.I.A.L.)
	strength = strength_value
	perception = perception_value
	endurance = endurance_value
	charisma = charisma_value
	intelligence = intelligence_value
	agility = agility_value
	luck = luck_value
	sequence_multiplier = sequence_multiplier_value
	
	# Status effects
	if not statuses_array.is_empty():
		statuses = statuses_array.duplicate() as Array[String]
	else:
		statuses = [] as Array[String]
	
	# Initialize skills base values (can be overridden in subclasses)
	_initialize_skills_base()
	
	# Calculate initial sequence (will be recalculated on combat start)
	calculate_sequence(false)
	
	# Recompute any derived stats (including skills)
	recompute_derived_stats()


# -------------------------
# Action Points System
# -------------------------
func spend_action_points(amount: int) -> bool:
	if amount <= 0:
		return true
	
	if action_points < amount:
		var was_out := action_points > 0
		action_points = 0
		_notify_ap_changed()
		if was_out:
			out_of_ap.emit()
		return false

	var prev_ap := action_points
	action_points -= amount
	_notify_ap_changed()

	if action_points <= 0 and prev_ap > 0:
		out_of_ap.emit()

	return true


func restore_action_points_full() -> void:
	if action_points != max_action_points:
		action_points = max_action_points
		_notify_ap_changed()


func restore_action_points(amount: int) -> void:
	if amount <= 0:
		return
	
	var prev_ap := action_points
	action_points = min(action_points + amount, max_action_points)
	
	if action_points != prev_ap:
		_notify_ap_changed()


func is_out_of_ap() -> bool:
	return action_points <= 0


func can_afford_action(ap_cost: int) -> bool:
	return action_points >= ap_cost


func can_be_paid_behaviour(behaviour: Node) -> bool:
	"""Check if we can afford the AP cost of a behaviour.
	Works with both TorsoBehaviour (player) and TorsoBehaviourNPC (NPCs)."""
	if behaviour == null:
		return false
	# Get AP cost from behaviour (both player and NPC behaviours have ap_cost)
	var ap_cost = behaviour.get("ap_cost")
	if ap_cost == null:
		return true  # No AP cost means it's always affordable
	return can_afford_action(ap_cost as int)


# Helper to emit AP changed signal only when needed
func _notify_ap_changed() -> void:
	action_points_changed.emit(action_points, max_action_points)


# -------------------------
# Health System
# -------------------------
func take_damage(amount: float) -> void:
	if is_invincible:
		print("[ActorResources] Damage blocked: actor is invincible")
		return
	if amount <= 0.0:
		print("[ActorResources] Damage blocked: amount is %.1f (<= 0)" % amount)
		return
	
	# Apply armor reduction
	var damage_after_armor := _apply_armor_reduction(amount)
	if damage_after_armor <= 0.0:
		print("[ActorResources] Damage blocked by armor: %.1f -> %.1f" % [amount, damage_after_armor])
		return
	
	var prev_health := health
	health = max(0.0, health - damage_after_armor)
	
	print("[ActorResources] take_damage: %.1f -> %.1f (after armor), health: %.1f -> %.1f" % [amount, damage_after_armor, prev_health, health])
	
	if health != prev_health:
		print("[ActorResources] Emitting health_changed signal: %.1f/%.1f" % [health, max_health])
		health_changed.emit(health, max_health)
		# Show damage indicator
		if actor != null:
			DamageIndicator.create_at_position(actor.global_position, DamageIndicator.IndicatorType.DAMAGE, damage_after_armor)
	else:
		print("[ActorResources] Health unchanged, signal NOT emitted")
	
	if health <= 0.0 and prev_health > 0.0:
		_on_death()


func gain_health(amount: float) -> void:
	if amount <= 0.0:
		return
	
	var prev_health := health
	health = min(health + amount, max_health)
	
	if health != prev_health:
		health_changed.emit(health, max_health)
		# Show heal indicator
		if actor != null:
			DamageIndicator.create_at_position(actor.global_position, DamageIndicator.IndicatorType.HEAL, amount)


func heal_full() -> void:
	if health != max_health:
		health = max_health
		health_changed.emit(health, max_health)


func _apply_armor_reduction(damage: float) -> float:
	# Default: no armor reduction (return full damage)
	# Override in subclasses to implement armor reduction formulas
	return damage


func _on_death() -> void:
	died.emit()
	# Override in subclasses for death handling


func is_alive() -> bool:
	return health > 0.0


# -------------------------
# Experience & Leveling
# -------------------------
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	
	experience += amount
	experience_gained.emit(amount)
	
	while experience >= max_experience:
		_level_up()


func _level_up() -> void:
	level += 1
	experience -= max_experience
	max_experience = int(max_experience * 1.2)  # Exponential growth
	
	level_changed.emit(level)
	
	# Recompute derived stats after level up
	recompute_derived_stats()


# -------------------------
# Status Effects
# -------------------------
func add_status(status: String) -> bool:
	if status.is_empty() or statuses.has(status):
		return false
	
	statuses.append(status)
	return true


func remove_status(status: String) -> bool:
	var index := statuses.find(status)
	if index == -1:
		return false
	
	statuses.remove_at(index)
	return true


func has_status(status: String) -> bool:
	return statuses.has(status)


func clear_all_statuses() -> void:
	if not statuses.is_empty():
		statuses.clear()


# -------------------------
# Sequence Calculation
# -------------------------
func calculate_sequence(is_combat_initiator: bool = false) -> void:
	# Base formula: sequence = (perception * 2) + agility
	var base_sequence := (perception * 2) + agility
	
	# Apply combat initiator bonus
	if is_combat_initiator:
		base_sequence *= 2
	
	# Apply perk multiplier (for future use)
	sequence = int(base_sequence * sequence_multiplier)


func get_sequence() -> int:
	return sequence


func set_base_stats(
		strength_value: int = 3,
		perception_value: int = 3,
		endurance_value: int = 3,
		charisma_value: int = 3,
		intelligence_value: int = 3,
		agility_value: int = 3,
		luck_value: int = 3
	) -> void:
	strength = strength_value
	perception = perception_value
	endurance = endurance_value
	charisma = charisma_value
	intelligence = intelligence_value
	agility = agility_value
	luck = luck_value
	
	# Recalculate skills when stats change
	recalculate_skills()


# -------------------------
# Skills System
# -------------------------
func _initialize_skills_base() -> void:
	# Initialize base skill values (override in subclasses to set custom bases)
	# Skills start at 0% by default
	pass


## Calculate skill value based on base + stat bonuses (Fallout 2 formula)
## Returns: base_skill + (stat_multiplier * stat_value), clamped to 0-100
func calculate_skill(skill_name: String) -> int:
	var base := skills_base[skill_name] as int
	var calculated: int
	
	match skill_name:
		"unarmed":
			# Unarmed: base + (Strength * 2) + (Endurance * 2)
			calculated = base + (strength * 2) + (endurance * 2)
		"melee_weapons":
			# Melee Weapons: base + (Strength * 2)
			calculated = base + (strength * 2)
		"small_guns":
			# Small Guns (pistols, revolvers): base + (Agility * 2)
			calculated = base + (agility * 2)
		"big_guns":
			# Big Guns (heavy weapons): base + (Endurance * 2)
			calculated = base + (endurance * 2)
		"energy_weapons":
			# Energy Weapons: base + (Perception * 2)
			calculated = base + (perception * 2)
		"throwing":
			# Throwing: base + (Agility * 2)
			calculated = base + (agility * 2)
		_:
			calculated = base
	
	return clamp(calculated, 0, 100)


## Recalculate all skills (called when stats change)
func recalculate_skills() -> void:
	for skill_name in skills_base.keys():
		var calculated_value := calculate_skill(skill_name)
		skills[skill_name] = calculated_value


## Get current skill value (base + stat bonuses)
func get_skill(skill_name: String) -> int:
	if not skills.has(skill_name):
		skills[skill_name] = calculate_skill(skill_name)
	return skills[skill_name] as int


## Set base skill value (before stat bonuses, clamped to 0-100)
func set_skill_base(skill_name: String, base_value: int) -> void:
	skills_base[skill_name] = clamp(base_value, 0, 100)
	skills[skill_name] = calculate_skill(skill_name)


## Add to base skill value
func add_skill_base(skill_name: String, amount: int) -> void:
	var current_base := skills_base[skill_name] as int
	set_skill_base(skill_name, current_base + amount)


## Get base skill value (without stat bonuses)
func get_skill_base(skill_name: String) -> int:
	return skills_base[skill_name] as int


# -------------------------
# Derived Stats (override in subclasses)
# -------------------------
func recompute_derived_stats() -> void:
	# Recalculate skills when stats change
	recalculate_skills()
	
	# Override in subclasses to compute max_health, max_action_points, armor, etc.
	# This is called after level ups, equipment changes, etc.
	pass


## Initialize humanoid stats (convenience method for all humanoids - enemies, NPCs, etc.)
## This is a generic initialization method that works for any humanoid actor
func initialize_humanoid_stats(
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


# -------------------------
# Utility
# -------------------------
func set_actor(actor_ref: Actor) -> void:
	actor = actor_ref


func get_health_percent() -> float:
	if max_health <= 0.0:
		return 0.0
	return health / max_health


func get_ap_percent() -> float:
	if max_action_points <= 0:
		return 0.0
	return float(action_points) / float(max_action_points)
