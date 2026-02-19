extends Node
class_name LegsBehavioursContainerNPC


var combat : HumanoidCombat
var actor : Actor
var skeleton : Skeleton3D
var legs : LegsMachineNPC
var area_awareness : AreaAwareness
var actions : LegsActionsContainerNPC
var legs_anim_settings : AnimationPlayer
var torso_anim_settings : AnimationPlayer

var behaviours : Dictionary


func forward_export_fields():
	for child in get_children():
		if child is LegsBehaviourNPC:
			child.actor = actor
			child.skeleton = skeleton
			child.combat = combat
			child.actions = actions
			child.legs = legs
			child.area_awareness = area_awareness
			child.legs_anim_settings = legs_anim_settings
			child.torso_anim_settings = torso_anim_settings
			behaviours[child.behaviour_name] = child


func get_by_name(behaviour_name : String) -> LegsBehaviourNPC:
	return behaviours[behaviour_name]

