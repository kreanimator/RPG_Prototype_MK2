extends Node
class_name TorsoBehaviourNPC

@export var legs_behaviour : LegsBehaviourNPC
@export var behaviour_name : String

@export_group("transition logic")
@export var priority : int = 0
@export var ap_cost : int = 0
@export var behaviour_map : Dictionary = {
		"idle" : "idle",
		"walk" : "walk",
		"run" : "run",
		"crouch" : "crouch",
		"crouch_idle": "crouch_idle",
		"interact": "interact",
		"attack": "attack",
		"hit": "hit"
	}
@export var interrupted_by_fall : bool = true
@export var maps_with_stance : bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var has_queued_move : bool = false
var queued_move : String
var has_forced_move : bool = false
var forced_move : String

var animations_source : AnimationPlayer
var animation_duration: float
var torso_anim_settings : AnimationPlayer
var simple_torso : AnimatorModifier
var locomotion_torso : Locomotion

var combat : HumanoidCombat
var actor : Actor
var skeleton : Skeleton3D
var legs : LegsMachineNPC
var torso : TorsoMachineNPC
var area_awareness : AreaAwareness
var resources : ActorResources

var enter_move_time : float

var actions : Dictionary
var current_action : TorsoActionNPC

var enter_behaviour_time : float

#region update logic

func _update(input : AIInputPackage, delta : float):
	legs.current_behaviour.update(input, delta)
	update(input, delta)

func update(_input : AIInputPackage, _delta : float):
	pass

#endregion

#region Transition logic

func check_relevance(input : AIInputPackage) -> String:	
	# Global falling logic: if behavior is interrupted by fall and actor is not on floor, go to midair
	if interrupted_by_fall and not actor.is_on_floor():
		# Don't interrupt if we're already in midair or jump_up
		if behaviour_name != "midair" and behaviour_name != "jump_up":
			return "midair"
	
	if has_queued_move and transitions_to_queued():
		try_force_move(queued_move)
		has_queued_move = false
	
	if has_forced_move:
		has_forced_move = false
		return forced_move
	
	return transition_logic(input)

func transition_logic(_input : AIInputPackage) -> String:
	return "okay"

func map_with_dictionary(input : AIInputPackage, map : Dictionary = behaviour_map):
	for action in input.actions:
		if map.keys().has(action):
			input.behaviour_names.append(map[action])
	return input

func switch_action_to(next_action : String, input : AIInputPackage):
	if current_action:
		current_action.on_exit_action()
	current_action = actions[next_action]
	current_action.setup_animator(input)
	current_action._on_enter_action(input)

func try_queue_move(new_queued_move : String):
	if not has_queued_move:
		queued_move = new_queued_move
		has_queued_move = true
	elif torso.behaviours[new_queued_move].priority > torso.behaviours[queued_move].priority:
		queued_move = new_queued_move

func try_force_move(new_forced_move : String):
	if not has_forced_move:
		has_forced_move = true
		forced_move = new_forced_move
	elif torso.behaviours[new_forced_move].priority >= torso.behaviours[forced_move].priority:
		forced_move = new_forced_move

func _on_enter_behaviour(input : AIInputPackage):
	mark_enter_behaviour()
	choose_initial_behaviour(input)
	legs_behaviour.torso_behaviour = self
	legs.switch_to(legs_behaviour, input)
	on_enter_behaviour(input)

func choose_initial_behaviour(_input : AIInputPackage):
	pass

func on_enter_behaviour(_input : AIInputPackage):
	pass

func _on_exit_behaviour():
	current_action = null
	on_exit_behaviour()

func on_exit_behaviour():
	pass

func best_input_that_can_be_paid(input : AIInputPackage) -> String:
	input.behaviour_names.sort_custom(torso.behaviours_priority_sort)
	for behaviour_nm in input.behaviour_names:
		if not torso.behaviours.has(behaviour_nm):
			continue
		var behaviour = torso.behaviours[behaviour_nm]
		# Check if we can pay for this behaviour BEFORE selecting it
		if resources and resources.can_be_paid_behaviour(behaviour):
			if behaviour == self:
				return "okay"
			else:
				return behaviour_nm
	# If no affordable behaviour found, return idle (which should always be affordable)
	return "idle"

func best_input_inclusive(input : AIInputPackage) -> String:
	input.behaviour_names.sort_custom(torso.behaviours_priority_sort)
	for behaviour in input.behaviour_names:
		return behaviour
	return "throwing because for some reason input.actions doesn't contain even idle"  

#endregion 

#region Double Legs users
func setup_legs_animator(_previous_action : LegsActionNPC, _input : AIInputPackage):
	pass

func update_legs(_input : AIInputPackage, _delta : float):
	pass
#endregion

#region Backend Getters

func accepts_queueing() -> bool:
	return false

func transitions_to_queued() -> bool:
	return false

#endregion

#region Time Measurements
func mark_enter_behaviour():
	enter_behaviour_time = Time.get_unix_time_from_system()

func get_progress() -> float:
	var now = Time.get_unix_time_from_system()
	return now - enter_behaviour_time

func behaves_longer_than(time : float) -> bool:
	return get_progress() >= time

func behaves_less_than(time : float) -> bool:
	return get_progress() < time

func behaves_between(start : float, finish : float) -> bool:
	var progress = get_progress()
	return progress >= start and progress <= finish
#endregion

func _init_behaviour():
	init_behaviour()
	for child in get_children():
		if child is TorsoActionNPC:
			child.parent_behaviour = self
			child.actor = actor
			child.combat = combat
			child.torso = torso
			child.animations_source = animations_source
			child.simple_torso = simple_torso
			if child.animation:
				child.animation_duration = animations_source.get_animation(child.animation).length
			child.torso_anim_settings = torso_anim_settings
			actions[child.action_name] = child
	actions["null"] = null

func init_behaviour():
	pass


# Default turn target position: straight ahead of the actor.
# Specific behaviours (interact / attack) override this to return
# the current interactable / enemy position.
func get_turn_target_position() -> Vector3:
	if actor == null:
		return Vector3.ZERO
	# Return a point 1 meter forward from actor's current position
	# In Godot, forward is typically -basis.z
	var forward_dir := -actor.global_transform.basis.z
	return actor.global_position + forward_dir
