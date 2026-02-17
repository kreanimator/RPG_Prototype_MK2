extends ActorResources
class_name PlayerResources

# -------------------------
# Tunables / constants
# -------------------------

@export var ap_per_meter_walk: float = 0.7
@export var ap_per_meter_run: float = 0.5
@export var ap_per_meter_crouch: float = 0.9

# -------------------------
# Player-specific persisted state
# -------------------------

@export var god_mode: bool = false

var global_position: Vector3
var look_direction: Vector3
var level_name: String

var skill_points: int
var player_mass: float
var inventory_size: int

# -------------------------
# Player-specific derived values (runtime)
# -------------------------

var current_weight: float
var max_weight: float

# -------------------------
# Player-specific runtime references
# -------------------------

var model: PlayerModel

var stats_manager: StatsManager
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager

var _ap_meter_accum: float = 0.0
var _ap_cost_cache: Dictionary = {}  # Cache for AP costs by move mode


func _ready() -> void:
	super._ready()
	
	# Initialize AP cost cache
	_ap_cost_cache = {
		GameManager.MoveMode.WALK: ap_per_meter_walk,
		GameManager.MoveMode.RUN: ap_per_meter_run,
		GameManager.MoveMode.CROUCH: ap_per_meter_crouch,
	}
	
	if GameManager.game_state == GameManager.GameState.INVESTIGATION:
		restore_action_points_full()

	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)


func update(_delta: float) -> void:
	super.update(_delta)
	# Player-specific update logic can go here


func _init_stats(sm: StatsManager, im: InventoryManager = null, em: EquipmentManager = null) -> void:
	stats_manager = sm
	inventory_manager = im
	equipment_manager = em

	var initial_stats: Dictionary = stats_manager.get_stats()
	from_dict(initial_stats)
	recompute_derived_stats()


# -------------------------
# Derived stats
# -------------------------

func recompute_derived_stats() -> void:
	super.recompute_derived_stats()
	
	# Derived caps from stats manager
	max_health = stats_manager.get_max_health()
	max_weight = stats_manager.get_max_weight()
	max_action_points = stats_manager.get_max_action_points()
	armor = stats_manager.get_armor_value()

	# Derived current weight
	current_weight = inventory_manager.get_total_weight()
	
	# Clamp current values to caps
	health = clamp(health, 0.0, max_health)
	action_points = clamp(action_points, 0, max_action_points)


# -------------------------
# AP / movement
# -------------------------

func _on_game_state_changed(new_state: int, _reason: String) -> void:
	if new_state == GameManager.GameState.COMBAT:
		_stop_player_navigation()


func get_ap_per_meter() -> float:
	return _ap_cost_cache.get(GameManager.move_mode, ap_per_meter_run)


func spend_ap_for_movement(distance_moved_meters: float) -> void:
	if GameManager.game_state != GameManager.GameState.COMBAT:
		_ap_meter_accum = 0.0
		return
	
	if distance_moved_meters <= 0.0:
		return

	var ap_per_meter := get_ap_per_meter()
	_ap_meter_accum += distance_moved_meters * ap_per_meter

	var to_spend := int(floor(_ap_meter_accum))
	if to_spend <= 0:
		return

	var prev_ap := action_points
	spend_action_points(to_spend)
	_ap_meter_accum -= float(to_spend)

	# Handle out-of-AP only once
	if prev_ap > 0 and action_points <= 0:
		_handle_out_of_ap()


func spend_action_points(amount: int) -> bool:
	# In investigation mode, actions are free
	if GameManager.game_state != GameManager.GameState.COMBAT:
		GameManager.can_perform_action = true
		return true

	var prev_ap := action_points
	var result := super.spend_action_points(amount)

	# Handle out-of-AP only once
	if prev_ap > 0 and action_points <= 0:
		_handle_out_of_ap()

	return result


func restore_action_points_full() -> void:
	super.restore_action_points_full()
	GameManager.can_perform_action = true


func is_out_of_ap() -> bool:
	var result := super.is_out_of_ap()
	if result:
		_handle_out_of_ap()
	return result


# Consolidated out-of-AP handling
func _handle_out_of_ap() -> void:
	GameManager.can_perform_action = false
	_stop_player_navigation()


func _stop_player_navigation() -> void:
	var player := model.player
	player.set_target_position(player.global_position)
	
	var resolver := model.action_resolver as ActionResolver
	resolver.cancel_intent()
	
	player.player_visuals.cursor_manager.hide_target_point()


# -------------------------
# Combat / HP
# -------------------------

func can_be_paid_behaviour(behaviour: TorsoBehaviour) -> bool:
	if GameManager.game_state == GameManager.GameState.INVESTIGATION:
		return true

	var has_weapon := equipment_manager != null \
		and equipment_manager.current_weapon != null \
		and is_instance_valid(equipment_manager.current_weapon)

	if behaviour.behaviour_name == "attack" and not has_weapon:
		return can_afford_action(stats_manager.get_unarmed_action_cost())

	return can_afford_action(behaviour.ap_cost)


func take_damage(amount: float) -> void:
	# Player-specific checks before taking damage
	if god_mode:
		return
	
	if model and model.current_behaviour and model.current_behaviour.behaviour_name == "death":
		return

	# Call parent to handle actual damage
	super.take_damage(amount)

	# Player-specific death handling
	if health <= 0.0 and model and model.current_behaviour:
		model.current_behaviour.try_force_move("death")


func _apply_armor_reduction(damage: float) -> float:
	# Player currently doesn't use armor for damage reduction
	# (armor is just a stat display)
	# Override this if you want to implement armor-based damage reduction
	return damage


# -------------------------
# Progression
# -------------------------

func _level_up() -> void:
	super._level_up()
	# Player-specific: gain skill points on level up
	skill_points += 1


# -------------------------
# Serialization (Player-specific)
# -------------------------

func to_dict() -> Dictionary:
	return {
		"global_position": _vector3_to_array(global_position),
		"look_direction": _vector3_to_array(look_direction),
		"level_name": level_name,

		"level": level,
		"skill_points": skill_points,
		"experience": experience,
		"max_experience": max_experience,

		"hp_current": health,
		"statuses": statuses.duplicate()
	}


func from_dict(data: Dictionary) -> void:
	# Strict loading. Missing keys should crash.
	global_position = _array_to_vector3(data["global_position"])
	look_direction = _array_to_vector3(data["look_direction"])
	level_name = String(data["level_name"])
	
	level = int(data["level"])
	skill_points = int(data["skill_points"])
	experience = int(data["experience"])
	max_experience = int(data["max_experience"])
	health = float(data["hp_current"])
	
	# Load all base stats (S.P.E.C.I.A.L.)
	strength = int(data["strength"])
	perception = int(data["perception"])
	endurance = int(data["endurance"])
	charisma = int(data["charisma"])
	intelligence = int(data["intelligence"])
	agility = int(data["agility"])
	luck = int(data["luck"])

	# Load statuses
	var incoming_statuses = data["statuses"]
	statuses.clear()
	for s in incoming_statuses:
		statuses.append(String(s))
	
	# Calculate initial sequence (will be recalculated on combat start)
	calculate_sequence(false)


# Helper methods for serialization
func _vector3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _array_to_vector3(arr: Array) -> Vector3:
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
