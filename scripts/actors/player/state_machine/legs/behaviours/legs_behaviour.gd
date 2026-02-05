extends Node
class_name LegsBehaviour

@export var behaviour_name : String

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var combat : HumanoidCombat
var player : Player
var player_aim : PlayerAim
var skeleton : Skeleton3D
var legs : LegsMachine
var legs_anim_settings : AnimationPlayer
var torso_anim_settings : AnimationPlayer
var area_awareness : AreaAwareness

var torso_behaviour : TorsoBehaviour

var actions : LegsActionsContainer


func update(_input : InputPackage, _delta : float):
	pass


func switch_to(next_action_name : String, input : InputPackage):
	#prints(behaviour_name, legs.current_action.action_name, " -> ", next_action_name)
	var previous_action = legs.current_action
	legs.current_action.on_exit_action()
	legs.current_action = actions.get_by_name(next_action_name)
	legs.current_action.setup_animator(previous_action, input)
	legs.current_action._on_enter_action(input)


func on_enter_behaviour(_input : InputPackage):
	pass


func on_exit_behaviour():
	pass
