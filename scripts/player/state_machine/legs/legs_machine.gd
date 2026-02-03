extends Node
class_name LegsMachine

var player : Player

@export var area_awareness : AreaAwareness
@export var legs_anim_settings : AnimationPlayer
@export var torso_anim_settings : AnimationPlayer
@export var skeleton : Skeleton3D
@export var torso : TorsoMachine

@export var behaviours : LegsBehavioursContainer
@export var actions : LegsActionsContainer

@export var locomotion_animator : Locomotion
@export var simple_animator : AnimatorModifier

@onready var current_behaviour : LegsBehaviour = $Behaviours/Idle
@onready var current_action : LegsAction = $Actions/Idle

enum MotionType { IDLE, WALK, RUN }
var current_motion_type : MotionType = MotionType.IDLE

var last_y_speed : float

func switch_to(next_legs_behaviour : LegsBehaviour, input : InputPackage):
	if next_legs_behaviour != current_behaviour or next_legs_behaviour.behaviour_name == "double_legs":
		current_behaviour.on_exit_behaviour()
		print("legs " + current_behaviour.behaviour_name + " -> " + next_legs_behaviour.behaviour_name)
		current_behaviour = next_legs_behaviour
		current_behaviour.torso_behaviour = torso.current_behaviour
		current_behaviour.on_enter_behaviour(input)

func forward_export_fields():
	actions.player = player
	actions.skeleton = skeleton
	actions.legs = self
	actions.legs_anim_settings = legs_anim_settings
	actions.torso_anim_settings = torso_anim_settings
	actions.forward_export_fields()
	
	behaviours.legs = self
	behaviours.player = player
	behaviours.skeleton = skeleton
	behaviours.actions = actions
	behaviours.area_awareness = area_awareness
	behaviours.legs_anim_settings = legs_anim_settings
	behaviours.torso_anim_settings = torso_anim_settings
	
	behaviours.forward_export_fields()

func behaviour_by_name(behaviour_name : String):
	return behaviours.get_by_name(behaviour_name)