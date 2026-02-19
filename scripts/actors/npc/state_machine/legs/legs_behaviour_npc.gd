extends Node
class_name LegsBehaviourNPC

@export var behaviour_name : String

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var combat : HumanoidCombat
var actor : Actor
var skeleton : Skeleton3D
var legs : LegsMachineNPC
var legs_anim_settings : AnimationPlayer
var torso_anim_settings : AnimationPlayer
var area_awareness : AreaAwareness

var torso_behaviour : TorsoBehaviourNPC

var actions : LegsActionsContainerNPC


func update(_input : AIInputPackage, _delta : float):
	pass


func switch_to(next_action_name : String, input : AIInputPackage):
	#prints(behaviour_name, legs.current_action.action_name, " -> ", next_action_name)
	var previous_action = legs.current_action
	legs.current_action.on_exit_action()
	legs.current_action = actions.get_by_name(next_action_name)
	legs.current_action.setup_animator(previous_action, input)
	legs.current_action._on_enter_action(input)


func on_enter_behaviour(_input : AIInputPackage):
	pass


func on_exit_behaviour():
	pass

