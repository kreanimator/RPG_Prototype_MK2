extends SkeletonModifier3D
class_name AnimatorModifier

@export var animations_storage : AnimationPlayer #AnimationSource
@onready var skeleton : Skeleton3D = get_skeleton()

@export var white_list : SkeletonMask
@export var bone_track_map : BoneTrackMap #= preload("res://Player/Model/SkeletonModifiers/kaj_skeleton_track_map.res")
@export var provides_root_velocity : bool

var current_animation : Animation
var current_animation_cycling : bool = true
var current_animation_progress : float = 0 #seconds
var animation_speed : float = 1.0  # Speed multiplier for animation playback

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

var pos_track : int
var rot_track : int

var derivative_delta : float = 0.02
var root_pos_track = 0

func _ready():
	current_animation = animations_storage.get_animation("idle")
	current_animation_cycling = current_animation.loop_mode == Animation.LoopMode.LOOP_LINEAR
	current_animation_progress = 0
	previous_animation = animations_storage.get_animation("idle")
	previous_animation_cycling = previous_animation.loop_mode == Animation.LoopMode.LOOP_LINEAR
	previous_animation_progress = 0


func play(next_animation : String, over_time : float = 0, speed: float = 1.0):
	#print("playing " + next_animation + " on " + name)
	
	animation_speed = speed
	blending_percentage = 1
	blending_percentage = 0
	blend_time_spent = 0
	is_blending = false
	
	if over_time < 0:
		push_error("can't blend two animations over " + str(over_time) + " baka")
	if not animations_storage.has_animation(next_animation):
		push_error("no such animation " + next_animation)
	last_processing_time = Time.get_unix_time_from_system()
	previous_animation = current_animation
	previous_animation_cycling = current_animation_cycling
	previous_animation_progress = current_animation_progress
	current_animation = animations_storage.get_animation(next_animation)
	current_animation_progress = 0
	current_animation_cycling = current_animation.loop_mode == Animation.LoopMode.LOOP_LINEAR
	if over_time > 0:
		is_blending = true
		blend_duration = over_time
		blend_time_spent = 0
		blending_percentage = 0


func _process_modification():
	update_time()
	update_blend_values()
#	DEV_echo_debug()
	update_skeleton()


func update_skeleton():
	if white_list: #this actually is an awful untyped variable abuse, dirty af TODO kys
		bone_list = white_list.bones
	else:
		bone_list = skeleton.get_bone_count()
	
	for bone in bone_list:
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
	current_animation_progress += delta * animation_speed
	previous_animation_progress += delta
	if current_animation_progress > current_animation.length and current_animation_cycling:
		current_animation_progress = fmod(current_animation_progress, current_animation.length)
	if previous_animation_progress > previous_animation.length and previous_animation_cycling:
		previous_animation_progress = fmod(previous_animation_progress, previous_animation.length)


func update_blend_values():
	if is_blending:
		blend_time_spent += delta
		blending_percentage = blend_time_spent / blend_duration
		if blending_percentage >= 1:
			blending_percentage = 1
			blending_percentage = 0
			blend_time_spent = 0
			is_blending = false


func calculate_bone_pose(bone_idx : int, animation : Animation, progress : float) -> Transform3D:
	var resulting_transform : Transform3D
	
	pos_track = bone_track_map.get_pos_track(bone_idx)
	if pos_track != -1 and pos_track != root_pos_track:
		resulting_transform.origin = animation.position_track_interpolate(pos_track, progress)
	else:
		resulting_transform.origin = skeleton.get_bone_pose(bone_idx).origin
	
	rot_track = bone_track_map.get_rot_track(bone_idx)
	if rot_track != -1:
		resulting_transform.basis = Basis(animation.rotation_track_interpolate(rot_track, progress))
	else:
		resulting_transform.basis = skeleton.get_bone_pose(bone_idx).basis
	
	return resulting_transform


func bone_to_track_name(bone_index : int) -> String:
	return "KajSkeleton:" + skeleton.get_bone_name(bone_index)


func calculate_root_velocity() -> Vector3:
	var adjustment_delta : float = Time.get_unix_time_from_system() - last_processing_time
	var current_now : float = fmod(current_animation_progress + adjustment_delta, current_animation.length)
	var past : float = max(current_now - derivative_delta, 0)
	var future : float = min(current_now + derivative_delta, current_animation.length)
	var current_past_pos : Vector3 = current_animation.position_track_interpolate(root_pos_track, past)
	var current_future_pos : Vector3 = current_animation.position_track_interpolate(root_pos_track, future)
	var current_animation_velocity : Vector3 = (current_future_pos - current_past_pos) / (future - past)
	
	if is_blending:
		var previous_now : float = fmod(previous_animation_progress + adjustment_delta, previous_animation.length)
		past = max(previous_now - derivative_delta, 0)
		future = min(previous_now + derivative_delta, previous_animation.length)
		var previous_pas_pos : Vector3 = previous_animation.position_track_interpolate(root_pos_track, past)
		var previous_future_pos : Vector3 = previous_animation.position_track_interpolate(root_pos_track, future)
		var previous_animation_velocity : Vector3 = (previous_future_pos - previous_pas_pos) / (future - past)
		
		var adjusted_blending_percentage : float = (blend_time_spent + adjustment_delta) / blend_duration
		return lerp(previous_animation_velocity, current_animation_velocity, adjusted_blending_percentage)
	return current_animation_velocity
