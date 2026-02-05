extends Node
class_name LegsActionsContainer

var player : Player
var player_aim : PlayerAim
var skeleton : Skeleton3D
var combat : HumanoidCombat
var legs : LegsMachine
var legs_anim_settings : AnimationPlayer
var torso_anim_settings : AnimationPlayer

var actions : Dictionary


func forward_export_fields():
	for child in get_children():
		if child is LegsAction:
			child.player = player
			child.player_aim = player_aim
			child.skeleton = skeleton
			child.combat = combat
			child.legs = legs
			child.legs_anim_settings = legs_anim_settings
			child.torso_anim_settings = torso_anim_settings
			actions[child.action_name] = child


func get_by_name(action_name : String) -> LegsAction:
	return actions[action_name]
