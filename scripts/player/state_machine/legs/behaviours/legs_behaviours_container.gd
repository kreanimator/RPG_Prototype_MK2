extends Node
class_name LegsBehavioursContainer

var player : Player
var skeleton : Skeleton3D
var legs : LegsMachine
var area_awareness : AreaAwareness
var actions : LegsActionsContainer
var legs_anim_settings : AnimationPlayer
var torso_anim_settings : AnimationPlayer

var behaviours : Dictionary

func forward_export_fields():
	for child in get_children():
		if child is LegsBehaviour:
			child.player = player
			child.skeleton = skeleton
			child.actions = actions
			child.legs = legs
			child.area_awareness = area_awareness
			child.legs_anim_settings = legs_anim_settings
			child.torso_anim_settings = torso_anim_settings
			behaviours[child.behaviour_name] = child

func get_by_name(behaviour_name : String) -> LegsBehaviour:
	return behaviours[behaviour_name]