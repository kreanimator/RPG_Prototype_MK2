extends Node
class_name PlayerResources

# TODO heavily refactor, rn just copypasted the resource code

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
@export var movement_mode: String
@export var action_points: int
@export var max_action_points: int
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
const SPRINT_SPEED: float = 7.0
#endregion

	
func get_pos():
	return global_position


func toggle_movement_mode() -> void:
	if movement_mode == "walk":
		movement_mode = "run"
	else:
		movement_mode = "walk"
	print("Movement mode switched to: ", movement_mode)

func get_movement_speed() -> float:
	match movement_mode:
		"walk":
			return WALK_SPEED
		"run":
			return RUN_SPEED
		"sprint":
			return SPRINT_SPEED
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
	# Check if we have enough ap to pay for the behavior if in combat mode
	if GameManager.game_state == GameManager.GameState.INVESTIGATION:
		return true
	if action_points >= behaviour.ap_cost:
		return true
	return false

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
