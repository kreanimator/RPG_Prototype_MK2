extends Node
class_name PlayerResources

signal action_points_changed(ap: int, max_ap: int)

#region Core player properties
@export var god_mode : bool
@export var global_position : Vector3
@export var look_direction: Vector3
@export var level_name : String
#endregion

#region Progression system
@export var level: int
@export var skill_points: int
@export var experience: int
@export var max_experience : int
#endregion

#region Health and stamina system
@export var health : float
@export var max_health : float
@export var hp_regeneration : float
#endregion

#region Inventory and weight system
@export var current_weight : float
@export var max_weight : float
@export var player_mass : float
@export var inventory_size : int
#endregion

#region Movement settings
@export var action_points: int
@export var max_action_points: int
@export var ap_per_meter_walk: float = 0.7   # 1 AP per 4m
@export var ap_per_meter_run: float = 0.5     # 1 AP per 2m
@export var ap_per_meter_crouch: float = 0.9  # 1 AP per 5m
var _ap_meter_accum: float = 0.0
#endregion

#region Weapon system
enum WeaponState { HOLSTERED, MELEE, PISTOL }
@export var current_weapon_state: WeaponState
#endregion

#region Internal state
var statuses : Array[String]
var model : PlayerModel
var is_invincible : bool = false  # Invincibility flag (e.g., during roll)
#endregion

#region Constants
const WALK_SPEED : float = 3.5
const RUN_SPEED: float = 5.0
const CROUCH_SPEED: float = 7.0
#endregion

var stats_manager: StatsManager
var inventory_manager: InventoryManager
var equipment_manager: EquipmentManager

func _ready() -> void:
	# Start with full AP when not in combat
	if GameManager.game_state == GameManager.GameState.INVESTIGATION:
		restore_action_points_full()

	# Auto-restore when exiting combat
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)
		
func update(delta : float):
	pass
	
func _init_stats(sm: StatsManager, im: InventoryManager = null, em: EquipmentManager = null):
	stats_manager = sm
	inventory_manager = im
	equipment_manager = em
	print("[Resources init] path=", get_path(), " em=", equipment_manager, " player=", model.player if model else null)
	var initial_stats: Dictionary = sm.get_stats()
	from_dict(initial_stats)
	
	# Sync weight from InventoryManager after loading
	#if inventory_manager:
		#_sync_weight_from_manager()

func _on_game_state_changed(new_state: int, _reason: String) -> void:
	if new_state == GameManager.GameState.INVESTIGATION:
		restore_action_points_full()
	
func get_pos():
	return global_position

func get_ap_per_meter() -> float:
	# You can use GameManager.move_mode, or your movement_mode string
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
	# Only in combat
	if GameManager.game_state != GameManager.GameState.COMBAT:
		_ap_meter_accum = 0.0
		return
	if distance_moved_meters <= 0.0:
		return

	var ap_per_meter := get_ap_per_meter()
	if ap_per_meter <= 0.0:
		return

	_ap_meter_accum += distance_moved_meters * ap_per_meter

	# Spend whole AP points only
	var to_spend := int(floor(_ap_meter_accum))
	if to_spend <= 0:
		return

	var before := action_points
	action_points = max(action_points - to_spend, 0)
	_ap_meter_accum -= float(to_spend)

	# Debug output
	var mode_name = GameManager.MoveMode.keys()[GameManager.move_mode]
	print(
		"[AP] movement:",
		mode_name,
		"dist=", "%.2f" % distance_moved_meters,
		"ap/m=", "%.2f" % ap_per_meter,
		"spent=", to_spend,
		"AP:", before, "->", action_points
	)

	action_points_changed.emit(action_points, max_action_points)

func spend_action_points(amount: int) -> bool:
	if GameManager.game_state != GameManager.GameState.COMBAT:
		GameManager.can_perform_action = true
		return true # free outside combat (optional)

	amount = max(amount, 0)
	if action_points < amount:
		print("[AP] NOT ENOUGH: need=", amount, " have=", action_points)
		GameManager.can_perform_action = false
		_stop_player_navigation()
		return false

	var before := action_points
	action_points -= amount
	print("[AP] spend:", amount, " AP:", before, "->", action_points)

	action_points_changed.emit(action_points, max_action_points)
	return true

func restore_action_points_full() -> void:
	action_points = max_action_points
	action_points_changed.emit(action_points, max_action_points)

func get_movement_speed(movement_mode: String) -> float:
	match movement_mode:
		"walk":
			return WALK_SPEED
		"run":
			return RUN_SPEED
		"sprint":
			return CROUCH_SPEED
		_:
			return WALK_SPEED

# Progression system
func add_experience(amount: int) -> void:
	experience += amount
	while experience >= max_experience:
		level_up()

func level_up() -> void:
	level += 1
	experience -= max_experience
	skill_points += 1
	max_experience = int(max_experience * 1.2)
	print("Level up! New level: ", level, " | Skill points: ", skill_points)


func can_be_paid_behaviour(behaviour : TorsoBehaviour) -> bool:
	# Free outside combat
	if GameManager.game_state == GameManager.GameState.INVESTIGATION:
		return true
	if behaviour.behaviour_name == "attack" and !equipment_manager.current_weapon:
		return action_points >= stats_manager.get_unarmed_action_cost()
	return action_points >= behaviour.ap_cost

func take_damage(amount : float):
	# Check invincibility (roll, i-frames, etc.)
	if is_invincible:
		return
	
	# Check god mode
	if god_mode:
		return
	
	# Don't take damage if already dead
	if model and model.current_behaviour and model.current_behaviour.behaviour_name == "death":
		return
	
	health -= amount
	
	# Trigger death if health reaches zero or below
	if health <= 0 and model and model.current_behaviour:
		model.current_behaviour.try_force_move("death")

func gain_health(amount : float):
	if health + amount <= max_health:
		health += amount
	else:
		health = max_health

func is_out_of_ap() -> bool:
	if action_points <= 0:
		GameManager.can_perform_action = false
		_stop_player_navigation()
		return true
	return false

func _stop_player_navigation() -> void:
	"""Stop player navigation and clear visual indicators when AP runs out."""
	if not model or not model.player:
		return
	
	var player = model.player
	
	# Stop navigation by setting target to current position
	if player.nav_agent:
		player.nav_agent.target_position = player.global_position
	
	# Clear visual target indicator
	if player.player_visuals and player.player_visuals.cursor_manager:
		player.player_visuals.cursor_manager.hide_target_point()


#region --- Serialization helpers ---

func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _array_to_vec3(arr: Array) -> Vector3:
	if arr.size() >= 3:
		return Vector3(arr[0], arr[1], arr[2])
	return Vector3.ZERO

func to_dict() -> Dictionary:
	# Sync weight from InventoryManager before serializing
	#if inventory_manager:
		#_sync_weight_from_manager()
	
	return {
		"global_position": _vec3_to_array(global_position),
		"look_direction": _vec3_to_array(look_direction),
		"level_name": level_name,
		"level": level,
		"skill_points": skill_points,
		"experience": experience,
		"max_experience": max_experience,
		"health": health,
		"max_health": max_health,
		"hp_regeneration": hp_regeneration,
		"current_weight": current_weight,  # Synced from InventoryManager
		"max_weight": max_weight,
		"player_mass": player_mass,
		"inventory_size": inventory_size,
		#"movement_mode": movement_mode,
		"current_weapon_state": WeaponState.keys()[current_weapon_state],
		"statuses": statuses if statuses != null else []
		# Note: inventory and equipment are handled by InventoryManager and EquipmentManager
	}

func from_dict(data: Dictionary) -> void:
	# Strict loading: assert every required key exists and is valid. No defaults, no branches.
	#Utilities.print_formatted_dict("Loading Player Stats", data, "PlayerResources")

	var gp = data["global_position"]
	global_position = Vector3(gp[0], gp[1], gp[2])
	var ld = data["look_direction"]
	look_direction = Vector3(ld[0], ld[1], ld[2])

	level_name = String(data["level_name"]) 
	level = int(data["level"]) 
	skill_points = int(data["skill_points"]) 
	experience = int(data["experience"]) 
	max_experience = int(data["max_experience"]) 
	health = float(data["health"]) 
	max_health = float(data["max_health"]) 
	hp_regeneration = float(data["hp_regeneration"]) 
	current_weight = float(data["current_weight"]) 
	max_weight = float(data["max_weight"]) 
	player_mass = float(data["player_mass"]) 
	inventory_size = int(data["inventory_size"]) 
	#movement_mode = String(data["movement_mode"]) 

	var state_name: String = String(data["current_weapon_state"])
	var idx: int = WeaponState.keys().find(state_name)
	if idx >= 0:
		current_weapon_state = idx as WeaponState
	else:
		current_weapon_state = WeaponState.HOLSTERED  # Default fallback

	var incoming_statuses = data["statuses"]
	var statuses_typed: Array[String] = []
	for s in incoming_statuses:
		statuses_typed.append(String(s))
	statuses = statuses_typed
#endregion
