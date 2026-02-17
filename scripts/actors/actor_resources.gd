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


# Helper to emit AP changed signal only when needed
func _notify_ap_changed() -> void:
	action_points_changed.emit(action_points, max_action_points)


# -------------------------
# Health System
# -------------------------
func take_damage(amount: float) -> void:
	if is_invincible or amount <= 0.0:
		return
	
	# Apply armor reduction
	var damage_after_armor := _apply_armor_reduction(amount)
	if damage_after_armor <= 0.0:
		return
	
	var prev_health := health
	health = max(0.0, health - damage_after_armor)
	
	if health != prev_health:
		health_changed.emit(health, max_health)
	
	if health <= 0.0 and prev_health > 0.0:
		_on_death()


func gain_health(amount: float) -> void:
	if amount <= 0.0:
		return
	
	var prev_health := health
	health = min(health + amount, max_health)
	
	if health != prev_health:
		health_changed.emit(health, max_health)


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
# Derived Stats (override in subclasses)
# -------------------------
func recompute_derived_stats() -> void:
	# Override in subclasses to compute max_health, max_action_points, armor, etc.
	# This is called after level ups, equipment changes, etc.
	pass


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
