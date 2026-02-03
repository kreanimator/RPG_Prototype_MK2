extends SkeletonModifier3D
class_name SplitBodyAnimator

const SKELETON_PREFIX: StringName = "%GeneralSkeleton:"

@export var animator : AnimationPlayer
@onready var skeleton = get_skeleton()

@export var white_list : SkeletonMask
#@export var is_active : bool = true

var current_animation : Animation
var current_animation_cycling : bool = true
var current_animation_progress : float = 0 #seconds

var previous_animation : Animation
var previous_animation_cycling : bool = true
var previous_animation_progress : float = 0    #seconds

var is_blending : bool = false
var blend_duration : float      # seconds
var blend_time_spent : float    # seconds
var blending_percentage : float # [0 ; 1]

var last_processing_time : float = 0 # seconds unix from system
var delta : float = 0                # seconds
var now : float = 0                  # seconds unix from system

var bone_list
var curr_transform : Transform3D
var previous_transform : Transform3D

## Track indices are kept local inside interpolation to avoid shared state

func _ready():
	### Debug print ###
	#if skeleton:
		#print_bone_list()
	if animator == null:
		push_warning("SplitBodyAnimator: animator is not assigned, trying to assign dynamically")
		return
			
	if animator.has_animation("idle"):
		current_animation = animator.get_animation("idle")
		previous_animation = animator.get_animation("idle")
	else:
		# Fallback to the first available animation if any
		var anim_list := animator.get_animation_list()
		if anim_list.size() > 0:
			var first_anim_name : String = anim_list[0]
			current_animation = animator.get_animation(first_anim_name)
			previous_animation = current_animation
		else:
			push_warning("SplitBodyAnimator: animator has no animations")
			return
	current_animation_cycling = current_animation.loop_mode == Animation.LoopMode.LOOP_LINEAR
	previous_animation_cycling = previous_animation.loop_mode == Animation.LoopMode.LOOP_LINEAR
	current_animation_progress = 0
	previous_animation_progress = 0


func play(next_animation : String, over_time : float = 0):
	if animator == null:
		return
	if over_time < 0:
		push_error("SplitBodyAnimator: blend time cannot be negative: " + str(over_time))
		over_time = 0
	if not animator.has_animation(next_animation):
		push_warning("SplitBodyAnimator: animation not found: " + next_animation)
		return
	last_processing_time = Time.get_unix_time_from_system()
	previous_animation = current_animation
	previous_animation_cycling = current_animation_cycling
	previous_animation_progress = current_animation_progress
	current_animation = animator.get_animation(next_animation)
	current_animation_progress = 0
	current_animation_cycling = current_animation.loop_mode == Animation.LoopMode.LOOP_LINEAR
	if over_time > 0:
		is_blending = true
		blend_duration = over_time
		blend_time_spent = 0
		blending_percentage = 0


func _process_modification():
	if animator == null or current_animation == null:
		return
	if not is_active:
		return
	update_time()
	update_blend_values()
#	DEV_echo_debug()
	update_skeleton()


func update_skeleton():
	var bones_to_process
	if white_list:
		bones_to_process = white_list.bones
	else:
		var count := skeleton.get_bone_count()
		bones_to_process = []
		bones_to_process.resize(count)
		for i in count:
			bones_to_process[i] = i
	
	for bone in bones_to_process:
		curr_transform = calculate_bone_pose(bone, current_animation, current_animation_progress)
		if is_blending:
			previous_transform = calculate_bone_pose(bone, previous_animation, previous_animation_progress)
			skeleton.set_bone_pose(bone, previous_transform.interpolate_with(curr_transform, blending_percentage))
		else:
			skeleton.set_bone_pose(bone, curr_transform)


func update_time():
	now = Time.get_unix_time_from_system()
	delta = now - last_processing_time
	last_processing_time = now

	current_animation_progress += delta
	previous_animation_progress += delta
	if current_animation_cycling and current_animation.length > 0 and current_animation_progress > current_animation.length:
		current_animation_progress = fmod(current_animation_progress, current_animation.length)
	if previous_animation_cycling and previous_animation.length > 0 and previous_animation_progress > previous_animation.length:
		previous_animation_progress = fmod(previous_animation_progress, previous_animation.length)


func update_blend_values():
	if is_blending:
		if blend_duration <= 0:
			blending_percentage = 1
		else:
			blend_time_spent += delta
			blending_percentage = blend_time_spent / blend_duration
		if blending_percentage >= 1:
			blending_percentage = 1
			is_blending = false


func calculate_bone_pose(bone_idx : int, animation : Animation, progress : float) -> Transform3D:
	var resulting_transform : Transform3D = Transform3D()
	var bone_pose := skeleton.get_bone_pose(bone_idx)
	
	var pos_track : int = animation.find_track(bone_to_track_name(bone_idx), Animation.TYPE_POSITION_3D)
	if pos_track != -1:
		resulting_transform.origin = animation.position_track_interpolate(pos_track, progress)
	else:
		resulting_transform.origin = bone_pose.origin
	
	var rot_track : int = animation.find_track(bone_to_track_name(bone_idx), Animation.TYPE_ROTATION_3D)
	if rot_track != -1:
		resulting_transform.basis = Basis(animation.rotation_track_interpolate(rot_track, progress))
	else:
		resulting_transform.basis = bone_pose.basis
	
	return resulting_transform


func bone_to_track_name(bone_index : int) -> String:
	return SKELETON_PREFIX + skeleton.get_bone_name(bone_index)

func print_bone_list() -> void:
	var bone_count := skeleton.get_bone_count()
	print("Skeleton has %d bones:" % bone_count)
	for i in range(bone_count):
		var bone_name := skeleton.get_bone_name(i)
		print("%d: %s" % [i, bone_name])

#func DEV_echo_debug():
	#print(name + " " + str(influence))
