extends Node
class_name PlayerResources

signal action_points_changed(ap: int, max_ap: int)
signal out_of_ap()

# -------------------------
# Tunables / constants
# -------------------------

@export var ap_per_meter_walk: float = 0.7
@export var ap_per_meter_run: float = 0.5
@export var ap_per_meter_crouch: float = 0.9

# -------------------------
# Persisted state
# -------------------------

@export var god_mode: bool = false

var global_position: Vector3
var look_direction: Vector3
var level_name: String

var level: int
var skill_points: int
var experience: int
var max_experience: int

# Current values (max values are derived)
var health: float
var hp_regeneration: float

var player_mass: float
var inventory_size: int

var action_points: int
var max_action_points: int

var statuses: Array[String] = []

# -------------------------
# Derived values (runtime)
# -------------------------

var max_health: float
var current_weight: float
var max_weight: float
var armor: int
# -------------------------
# Runtime references
# -------------------------

var model: PlayerModel
var is_invincible: bool = false

var stats_manager: StatsManager
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager

var _ap_meter_accum: float = 0.0


func _ready() -> void:
	if GameManager.game_state == GameManager.GameState.INVESTIGATION:
		restore_action_points_full()

	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)


func update(_delta: float) -> void:
	pass


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
	# Derived caps
	max_health = stats_manager.get_max_health()
	max_weight = stats_manager.get_max_weight()
	max_action_points = stats_manager.get_max_action_points()

	# Derived current weight
	if inventory_manager:
		current_weight = inventory_manager.get_total_weight()
		
	armor = stats_manager.get_armor_value()
	# Clamp current values to caps
	health = clamp(health, 0.0, max_health)
	action_points = clamp(action_points, 0, max_action_points)

	# Notify UI (important when max AP changes after load/level-up)
	action_points_changed.emit(action_points, max_action_points)


# -------------------------
# AP / movement
# -------------------------

func _on_game_state_changed(new_state: int, _reason: String) -> void:
	if new_state == GameManager.GameState.INVESTIGATION:
		return

	if new_state == GameManager.GameState.COMBAT:
		_stop_player_navigation()
		restore_action_points_full()


func get_ap_per_meter() -> float:
	match GameManager.move_mode:
		GameManager.MoveMode.WALK:
			return ap_per_meter_walk
		GameManager.MoveMode.RUN:
			return ap_per_meter_run
		GameManager.MoveMode.CROUCH:
			return ap_per_meter_crouch
		_:
			return ap_per_meter_run


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

	action_points = max(action_points - to_spend, 0)
	_ap_meter_accum -= float(to_spend)

	action_points_changed.emit(action_points, max_action_points)

	if prev_ap > 0 and action_points <= 0:
		GameManager.can_perform_action = false
		_stop_player_navigation()
		out_of_ap.emit()


func spend_action_points(amount: int) -> bool:
	if GameManager.game_state != GameManager.GameState.COMBAT:
		GameManager.can_perform_action = true
		return true

	var prev_ap := action_points

	if action_points < amount:
		action_points = 0
		action_points_changed.emit(action_points, max_action_points)
		GameManager.can_perform_action = false
		_stop_player_navigation()
		out_of_ap.emit()
		return false

	action_points -= amount
	action_points_changed.emit(action_points, max_action_points)

	if prev_ap > 0 and action_points <= 0:
		GameManager.can_perform_action = false
		_stop_player_navigation()
		out_of_ap.emit()

	return true


func restore_action_points_full() -> void:
	GameManager.can_perform_action = true
	action_points = max_action_points
	action_points_changed.emit(action_points, max_action_points)


func is_out_of_ap() -> bool:
	if action_points <= 0:
		GameManager.can_perform_action = false
		_stop_player_navigation()
		return true
	return false


func _stop_player_navigation() -> void:
	if model == null or model.player == null:
		return

	var player := model.player
	player.set_target_position(player.global_position)
	print("STOP NAV: target=", player.nav_agent.target_position, " pos=", player.global_position)
	var resolver := model.action_resolver as ActionResolver
	resolver.cancel_intent()
	if player.player_visuals and player.player_visuals.cursor_manager:
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
		return action_points >= stats_manager.get_unarmed_action_cost()

	return action_points >= behaviour.ap_cost


func take_damage(amount: float) -> void:
	if is_invincible or god_mode:
		return
	if model and model.current_behaviour and model.current_behaviour.behaviour_name == "death":
		return

	health -= amount

	if health <= 0.0 and model and model.current_behaviour:
		model.current_behaviour.try_force_move("death")


func gain_health(amount: float) -> void:
	health = min(health + amount, max_health)


# -------------------------
# Progression
# -------------------------

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= max_experience:
		_level_up()


func _level_up() -> void:
	level += 1
	experience -= max_experience
	skill_points += 1
	max_experience = int(max_experience * 1.2)

	recompute_derived_stats()


# -------------------------
# Serialization
# -------------------------

func to_dict() -> Dictionary:
	return {
		"global_position": [global_position.x, global_position.y, global_position.z],
		"look_direction": [look_direction.x, look_direction.y, look_direction.z],
		"level_name": level_name,

		"level": level,
		"skill_points": skill_points,
		"experience": experience,
		"max_experience": max_experience,

		"hp_current": health,
		"statuses": statuses
	}


func from_dict(data: Dictionary) -> void:
	# Strict loading. Missing keys should crash.

	var gp = data["global_position"]
	global_position = Vector3(gp[0], gp[1], gp[2])

	var ld = data["look_direction"]
	look_direction = Vector3(ld[0], ld[1], ld[2])

	level_name = String(data["level_name"])
	level = int(data["level"])
	skill_points = int(data["skill_points"])
	experience = int(data["experience"])
	max_experience = int(data["max_experience"])

	health = float(data["hp_current"])

	var incoming_statuses = data["statuses"]
	statuses.clear()
	for s in incoming_statuses:
		statuses.append(String(s))
