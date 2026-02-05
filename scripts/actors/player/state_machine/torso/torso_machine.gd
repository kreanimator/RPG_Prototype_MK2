extends Node
class_name TorsoMachine

var behaviours : Dictionary # {String : TorsoBehaviour} 

var player : CharacterBody3D
@export var combat : HumanoidCombat
@export var area_awareness : AreaAwareness
@export var legs : LegsMachine
@export var resources : PlayerResources

@export var default_behaviour : TorsoBehaviour

@export_group("animation")
@export var skeleton : Skeleton3D
@export var animations_source : AnimationPlayer
@export var torso_anim_settings : AnimationPlayer
@export var simple_torso : AnimatorModifier
@export var locomotion_torso : Locomotion

var current_behaviour : TorsoBehaviour
var current_action : TorsoAction

func forward_export_fields(child : TorsoBehaviour):
	child.legs = legs
	child.player = player
	child.skeleton = skeleton
	child.combat = combat
	child.torso = self
	child.area_awareness = area_awareness
	child.resources = resources
	
	child.animations_source = animations_source
	child.torso_anim_settings = torso_anim_settings
	child.simple_torso = simple_torso
	child.locomotion_torso = locomotion_torso
	
	child._init_behaviour()

func get_behaviour_by_name(behaviour_name : String):
	return behaviours[behaviour_name]

func accept_behaviours():
	behaviours = {}
	var counter : int = 1
	for child in get_children():
		if child is TorsoBehaviour:
			behaviours[child.behaviour_name] = child
			if child.priority == 0:
				child.priority = counter
			forward_export_fields(child)
			counter = counter + 1

func behaviours_priority_sort(a : String, b : String):
	if behaviours[a].priority > behaviours[b].priority:
		return true
	else:
		return false
