extends Node
class_name TorsoAction

var player : Player
var skeleton : Skeleton3D
var combat : HumanoidCombat
var torso : TorsoMachine
var animations_source : AnimationPlayer
var torso_anim_settings : AnimationPlayer

var parent_behaviour : TorsoBehaviour

@export var action_name : String
@export var anim_settings : String = "simple"
@export var animation : String
var simple_torso : SkeletonModifier3D

var enter_action_time : float
var animation_duration : float = 0

func update(_input : InputPackage, _delta : float):
	pass

func setup_animator(_input : InputPackage):
	pass

func _on_enter_action(input : InputPackage):
	torso.current_action = self
	mark_enter_action()
	on_enter_action(input)

func on_enter_action(_input : InputPackage):
	pass

func on_exit_action():
	pass

func animation_ended() -> bool:
	if anim_settings == "simple" or anim_settings == "simple_and_look_at":
		return acts_longer_than(animation_duration)
	return false

#region Time Measurements
func mark_enter_action():
	enter_action_time = Time.get_unix_time_from_system()

func get_progress() -> float:
	var now = Time.get_unix_time_from_system()
	return now - enter_action_time

func acts_longer_than(time : float) -> bool:
	return get_progress() >= time

func acts_less_than(time : float) -> bool:
	return get_progress() < time

func acts_between(start : float, finish : float) -> bool:
	var progress = get_progress()
	return progress >= start and progress <= finish
#endregion
