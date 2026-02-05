extends SkeletonModifier3D
class_name SkeletonModifierMeta

@onready var skeleton : Skeleton3D = get_skeleton()

@onready var animation_player : AnimationPlayer = $"../../SkeletonAnimator"

@onready var debug_modifier = $"../Outie"
@export var provides_root_velocity : bool

 # one-time pass to create a BoneTrackMap, TODO demonstrate and delete
func _ready():
	BoneTrackMap.bake(get_skeleton(), animation_player.get_animation("Idle"), "res://scripts/player/state_machine/resources/RPG_prototype_bone_track_map.res")
#
func _process_modification():
	restore_pose()
	for child in get_skeleton().get_children():
		if child is SkeletonModifier3D:
			if child.influence == 0:
				child.active = false
			else:
				child.active = true

func restore_pose():
	var cache = debug_modifier.cache as Dictionary
	if not cache.is_empty():
		for bone in get_skeleton().get_bone_count():
			skeleton.set_bone_pose(bone, cache[bone])
