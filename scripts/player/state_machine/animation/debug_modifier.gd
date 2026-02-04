extends SkeletonModifier3D
class_name DebugModifier

@onready var torso_locomotion = $"../TorsoLoco" as Locomotion
@onready var legs_locomotion = $"../LegsLoco" as Locomotion


@onready var legs_simple = $"../LegsSimple" as AnimatorModifier
@onready var torso_simple = $"../TorsoSimple" as AnimatorModifier

@onready var legs_settings = $"../../LegsAnimationSettings" as AnimationPlayer
@onready var torso_settings = $"../../TorsoAnimationSettings" as AnimationPlayer
#@onready var animation_player = $"../../AnimationPlayer"


#@onready var debug_label = $"animation debug label"

@onready var skeleton : Skeleton3D = get_skeleton()
@export var provides_root_velocity : bool

var last_pose : Vector3

var cache : Dictionary

func bake_pose():
	for bone in skeleton.get_bone_count():
		cache[bone] = skeleton.get_bone_pose(bone)

func _process_modification():
	bake_pose()
#	debug_my_garbage()

#func debug_my_garbage():
	#$"../../DebugLabel".text = $"../TorsoSimple".current_animation.animation_name + " " + str($"../TorsoSimple".current_animation_progress) + "\n"
	#$"../../DebugLabel".text += $"../LegsSimple".current_animation.animation_name + " " + str($"../LegsSimple".current_animation_progress) + "\n"
	
