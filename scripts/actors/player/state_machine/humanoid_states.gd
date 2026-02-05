extends Node
class_name HumanoidStates

@export_group("Humanoid Modifiers")
@export var player : CharacterBody3D
@export var animation_settings : AnimationPlayer
@export var skeleton : Skeleton3D
@export var combat : HumanoidCombat
@export var area_awareness : AreaAwareness
@export var moves_data_repo : MovesDataRepository
#@export var legs : Legs

@export_group("Body Animators")
@export var legs_animator : SplitBodyAnimator
@export var torso_animator : SplitBodyAnimator


var states : Dictionary # { string : State }, where string is Move heirs name


func accept_moves():
	for child in get_children():
		if child is State:
			states[child.state_name] = child
			child.player = player 
			#child.resources = player.player_data
			child.moves_data_repo = moves_data_repo
			child.container = self
			child.duration = moves_data_repo.get_duration(child.backend_animation)
			child.area_awareness = area_awareness
			#child.legs = legs
			child.assign_combos()
	

func states_priority_sort(a: String, b: String) -> bool:
	if states[a].priority > states[b].priority:
		return true
	return false


func get_move_by_name(state_name : String) -> State:
	return states[state_name]
