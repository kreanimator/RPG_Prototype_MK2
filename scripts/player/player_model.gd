extends Node
class_name PlayerModel


var player: Player
@onready var skeleton = %GeneralSkeleton as Skeleton3D
@onready var skeleton_animator: AnimationPlayer = $SkeletonAnimator

func _ready() -> void:
	player = get_parent()
	Utils.print_bone_indexes_with_names(skeleton)

func temp_play_idle():
	skeleton_animator.play("Idle")
	
func temp_play_run():
	skeleton_animator.play("Jog_Fwd")
