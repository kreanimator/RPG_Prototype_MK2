extends Node
class_name State

var player: CharacterBody3D
var resources : PlayerResources

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var animation : String
@export var backend_animation : String
@export var animator : AnimationPlayer
@export var state_name: String
@export var stamina_cost : float = 0
@export var tracking_angular_speed : float = 10
@onready var combos : Array[Combo]
@export var priority : int
@export var is_rotatable: bool = false

var has_queued_move : bool = false
var queued_move : String = "none, drop error please"
var has_forced_move : bool = false
var forced_move : String = "none, drop error please"
var enter_state_time : float
var moves_data_repo : MovesDataRepository
var area_awareness : AreaAwareness
var container : HumanoidStates
var duration : float
enum AnimationScope { FULL_BODY, LEGS, TORSO, SPLIT }
@export var animation_scope : AnimationScope = AnimationScope.FULL_BODY



func check_relevance(input : InputPackage) -> String:
	if has_forced_move:
		has_forced_move = false
		return forced_move
	
	# Check for weapon toggle in all states
	var model = player.model as PlayerModel
	if model and input.actions.has("holster_weapon"):
		if model.is_weapon_holstered:
			return "unholster_weapon"
		else:
			return "holster_weapon"
	
	check_combos(input)
	return default_lifecycle(input)
	

func update(_input: InputPackage, _delta: float):
	pass


func update_resources(delta: float):
	assert(resources != null, "resources is null in state!")
	resources.update(delta)
	

func on_enter_state() -> void:
	pass
	

func on_exit_state() -> void:
	pass
	

func check_combos(input : InputPackage):
	assert(combos != null, "combos array is null!")
	
	var available_combos = get_children()
	for combo : Combo in available_combos:
		if combo.is_triggered(input):
			has_queued_move = true
			queued_move = combo.triggered_move


func process_input_vector(input : InputPackage, delta : float):
	var input_direction = (player.camera_mount.basis * Vector3(-input.input_direction.x, 0, -input.input_direction.y)).normalized()
	var face_direction = player.basis.z
	var angle = face_direction.signed_angle_to(input_direction, Vector3.UP)
	player.rotate_y(clamp(angle, -tracking_angular_speed * delta, tracking_angular_speed * delta))

func best_input_that_can_be_paid(input : InputPackage) -> String:
	assert(resources != null, "resources is null!")
	assert(player != null, "player is null!")
	assert(player.model != null, "player.model is null!")
	
	input.actions.sort_custom(container.states_priority_sort)
	for action in input.actions:
		if resources.can_be_paid(player.model.states_container.states[action]):
			if player.model.states_container.states[action] == self:
				return "okay"
			else:
				return action
	return "throwing because for some reason input.actions doesn't contain even idle"  


func mark_enter_state():
	enter_state_time = Time.get_unix_time_from_system()


func get_progress() -> float:
	var now = Time.get_unix_time_from_system()
	return now - enter_state_time


func works_longer_than(time : float) -> bool:
	if get_progress() >= time:
		return true
	return false


func works_less_than(time : float) -> bool:
	if get_progress() < time: 
		return true
	return false


func works_between(start : float, finish : float) -> bool:
	var progress = get_progress()
	if progress >= start and progress <= finish:
		return true
	return false
	

func is_vulnerable() -> bool:
	return moves_data_repo.get_vulnerable(backend_animation, get_progress())


func is_interruptable() -> bool:
	return moves_data_repo.get_interruptable(backend_animation, get_progress())


func is_parryable() -> bool:
	return moves_data_repo.get_parryable(backend_animation, get_progress())


func default_lifecycle(input : InputPackage):
	if works_longer_than(duration):
		return best_input_that_can_be_paid(input)
	return "okay"


func get_root_position_delta(delta_time : float) -> Vector3:
	return moves_data_repo.get_root_delta_pos(backend_animation, get_progress(), delta_time)


func assign_combos():
	for child in get_children():
		if child is Combo:
			combos.append(child)
			child.move = self
			

func form_hit_data(_weapon : Weapon) -> HitData:
	return HitData.blank()


func react_on_hit(hit : HitData):
	if is_vulnerable():
		resources.take_damage(hit.damage)
	if is_interruptable():
		try_force_move("hit")
	hit.queue_free()


func react_on_parry(_hit : HitData):
	try_force_move("parried")


func toggle_look_at_modifier(value: bool) -> void:
	var look_at_modifier = player.model.spine_look_at_modifier
	if look_at_modifier and look_at_modifier.has_method("toggle_modifier"):
		look_at_modifier.toggle_modifier(value)
		
		
func try_force_move(new_forced_move : String):
	if not has_forced_move:
		has_forced_move = true
		forced_move = new_forced_move
	elif container.states[new_forced_move].priority >= container.states[forced_move].priority:
		forced_move = new_forced_move
		
