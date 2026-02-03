extends SkeletonModifier3D
class_name Locomotion

@onready var skeleton : Skeleton3D = get_skeleton()
@export var animations_source : AnimationPlayer

@export var anglular_speed : float = 0.05    # radians per frame

@export var white_list : SkeletonMask
@export var bone_track_map : BoneTrackMap
@export var provides_root_velocity : bool

var input_vector : Vector2

var curr_direction : Vector2 = Vector2(1, 0)
var curr_left : Vector2
var curr_right : Vector2

var prev_direction : Vector2 = Vector2(0, 0)
var prev_left : Vector2
var prev_right : Vector2

var curr_progress : float
var curr_cycle_length : float
var curr_left_anim : Animation
var curr_right_anim : Animation

var prev_progress : float
var prev_cycle_length : float
var prev_left_anim : Animation
var prev_right_anim : Animation

var root_pos_track = 0
var last_update : float
var now : float

var curr_direction_blending_percentage : float 
var prev_direction_blending_percentage : float 

var curr_directions_spectre : Dictionary
var curr_section_angle : float = PI / 4
var curr_sections_number : int = 8
var curr_dir_static : bool = false

var prev_directions_spectre : Dictionary
var prev_section_angle : float = PI / 4
var prev_sections_number : int = 8
var prev_dir_static : bool = false

var is_blending_spectres : bool = false
var blending_time_spent : float
var specters_blending_percentage : float
var spectre_blending_duration : float

var has_follower : bool = false
var follower : Locomotion

var bone_list
var curr_transform : Transform3D

var derivative_delta : float = 0.02

func _ready():
	curr_directions_spectre = {
		Vector2(0, 1) : "idle",
		(Vector2(-1, 0) + Vector2(0, 1)).normalized() : "idle",
		Vector2(-1, 0) : "idle",
		(Vector2(-1, 0) + Vector2(0, -1)).normalized() : "idle",
		Vector2(0, -1) : "idle",
		(Vector2(1, 0) + Vector2(0, -1)).normalized() : "idle",
		Vector2(1, 0) : "idle",
		(Vector2(0, 1) + Vector2(1, 0)).normalized() : "idle",
	}
	curr_right_anim = animations_source.get_animation("idle")
	prev_right_anim = animations_source.get_animation("idle")
	curr_dir_static = false
	curr_progress = 0
	curr_cycle_length = 1
	
	prev_directions_spectre = curr_directions_spectre

func transition(to_spectre : Dictionary, over_time = 0, first_direction : Vector2 = Vector2.ZERO, static_dir : bool = false):
	if over_time < 0:
		push_error("negative transition time in locomotion modifier")
		return
	
	prev_directions_spectre = curr_directions_spectre
	prev_progress = curr_progress
	prev_cycle_length = curr_cycle_length
	prev_sections_number = curr_sections_number
	prev_section_angle = curr_section_angle
	prev_dir_static = curr_dir_static
	prev_direction = curr_direction
	
	curr_directions_spectre = to_spectre
	curr_progress = 0
	var north_anim = animations_source.get_animation(to_spectre[Vector2(0,1)])
	curr_cycle_length = north_anim.length
	curr_sections_number = to_spectre.size()
	curr_section_angle = 2 * PI / curr_sections_number
	curr_dir_static = static_dir
	
	if over_time > 0:
		is_blending_spectres = true
		blending_time_spent = 0
		specters_blending_percentage = 0
		spectre_blending_duration = over_time
	
	if first_direction:
		input_vector = first_direction
		curr_direction = input_vector
		if not prev_dir_static:
			prev_direction = first_direction
	
	last_update = Time.get_unix_time_from_system()
	update_direction()
	
	if has_follower:
		follower.transition(to_spectre, over_time, first_direction, static_dir)

func _process_modification():
	update_time()
	update_direction()
	update_skeleton()

func update_time():
	now = Time.get_unix_time_from_system()
	var delta = now - last_update
	curr_progress += delta
	prev_progress += delta
	last_update = now
	
	if curr_progress > curr_cycle_length:
		if curr_right_anim.loop_mode == Animation.LoopMode.LOOP_LINEAR:
			curr_progress = fmod(curr_progress, curr_cycle_length)
		else:
			curr_progress = curr_cycle_length
	
	if prev_progress > prev_cycle_length:
		if prev_right_anim.loop_mode == Animation.LoopMode.LOOP_LINEAR:
			prev_progress = fmod(prev_progress, prev_cycle_length)
		else:
			prev_progress = prev_cycle_length
	
	if is_blending_spectres:
		blending_time_spent += delta
		specters_blending_percentage = blending_time_spent / spectre_blending_duration
		if specters_blending_percentage >= 1:
			blending_time_spent = 0
			specters_blending_percentage = 0
			is_blending_spectres = false

func set_input_vector(new_direction : Vector2):
	input_vector = new_direction
	if has_follower:
		follower.input_vector = new_direction

func update_direction():
	var angle = curr_direction.angle_to(input_vector)
	if not curr_dir_static:
		curr_direction = curr_direction.rotated(clamp(angle, -anglular_speed, anglular_speed))
	
	var absolute_angle = fmod(Vector2(0,1).angle_to(curr_direction) + 2 * PI, 2 * PI)
	
	var section = (int)( absolute_angle / curr_section_angle )
	curr_right = curr_directions_spectre.keys()[section]
	curr_left = curr_directions_spectre.keys()[(section + 1) % curr_sections_number]
	curr_right_anim = animations_source.get_animation(curr_directions_spectre[curr_right])
	curr_left_anim = animations_source.get_animation(curr_directions_spectre[curr_left])
	curr_direction_blending_percentage = curr_right.angle_to(curr_direction) / curr_section_angle
	
	if is_blending_spectres:
		angle = prev_direction.angle_to(input_vector)
		if not prev_dir_static:
			prev_direction = prev_direction.rotated(clamp(angle, -anglular_speed, anglular_speed))
		absolute_angle = fmod(Vector2(0,1).angle_to(prev_direction) + 2 * PI, 2 * PI)
		section = (int)(absolute_angle / prev_section_angle)
		prev_right = prev_directions_spectre.keys()[section]
		prev_left = prev_directions_spectre.keys()[(section + 1) % prev_sections_number]
		prev_right_anim = animations_source.get_animation(prev_directions_spectre[prev_right])
		prev_left_anim = animations_source.get_animation(prev_directions_spectre[prev_left])
		prev_direction_blending_percentage = prev_right.angle_to(prev_direction) / prev_section_angle

func update_skeleton():
	if white_list:
		bone_list = white_list.bones
	else:
		bone_list = skeleton.get_bone_count()
	
	for bone in bone_list:
		skeleton.set_bone_pose(bone, suggest_bone_pose(bone))

func suggest_bone_pose(bone : int) -> Transform3D:
	var track = bone_track_map.get_rot_track(bone)
	var resulting_rotation : Quaternion
	
	var curr_right_rot : Quaternion = curr_right_anim.rotation_track_interpolate(track, curr_progress)
	var curr_left_rot : Quaternion = curr_left_anim.rotation_track_interpolate(track, curr_progress)
	var curr_res_rot : Quaternion = lerp(curr_right_rot, curr_left_rot, curr_direction_blending_percentage)
	
	if is_blending_spectres:
		var prev_right_rot : Quaternion = prev_right_anim.rotation_track_interpolate(track, prev_progress)
		var prev_left_rot : Quaternion = prev_left_anim.rotation_track_interpolate(track, prev_progress)
		var prev_res_rot : Quaternion = lerp(prev_right_rot, prev_left_rot, prev_direction_blending_percentage)
		resulting_rotation = lerp(prev_res_rot, curr_res_rot, specters_blending_percentage)
	else:
		resulting_rotation = curr_res_rot
	
	track = bone_track_map.get_pos_track(bone)
	var resulting_position : Vector3
	
	if track == -1: 
		resulting_position = skeleton.get_bone_pose_position(bone)
	
	if bone != root_pos_track and track != -1:
		var curr_right_pos : Vector3 = curr_right_anim.position_track_interpolate(track, curr_progress)
		var curr_left_pos : Vector3 = curr_left_anim.position_track_interpolate(track, curr_progress)
		var curr_res_pos : Vector3 = lerp(curr_right_pos, curr_left_pos, curr_direction_blending_percentage)
		if is_blending_spectres:
			var prev_right_pos : Vector3 = prev_right_anim.position_track_interpolate(track, prev_progress)
			var prev_left_pos : Vector3 = prev_left_anim.position_track_interpolate(track, prev_progress)
			var prev_res_pos : Vector3 = lerp(prev_right_pos, prev_left_pos, prev_direction_blending_percentage)
			resulting_position = lerp(prev_res_pos, curr_res_pos, specters_blending_percentage)
		else:
			resulting_position = curr_res_pos
	
	return Transform3D(Basis(resulting_rotation), resulting_position)

func accept_follower(new_follower : Locomotion):
	has_follower = true
	follower = new_follower

func remove_follower():
	has_follower = false
	follower = null

func sync_and_follow(another_locomotion : Locomotion, over_time : float = 0):
	prev_directions_spectre = curr_directions_spectre
	prev_progress = curr_progress
	prev_cycle_length = curr_cycle_length
	prev_sections_number = curr_sections_number
	prev_section_angle = curr_section_angle
	prev_dir_static = curr_dir_static
	prev_direction = curr_direction
	
	curr_direction = another_locomotion.curr_direction
	
	curr_progress = another_locomotion.curr_progress
	curr_cycle_length = another_locomotion.curr_cycle_length
	last_update = another_locomotion.last_update
	now = another_locomotion.now
	
	curr_directions_spectre = another_locomotion.curr_directions_spectre
	curr_section_angle = another_locomotion.curr_section_angle
	curr_sections_number = another_locomotion.curr_sections_number
	curr_dir_static = another_locomotion.curr_dir_static
	
	if over_time > 0:
		is_blending_spectres = true
		blending_time_spent = 0
		specters_blending_percentage = 0
		spectre_blending_duration = over_time
	
	another_locomotion.accept_follower(self)

func calculate_root_velocity() -> Vector3:
	var resulting_velocity : Vector3
	var adjustment_delta : float = Time.get_unix_time_from_system() - last_update
	var curr_now : float = fmod(curr_progress + adjustment_delta, curr_cycle_length)
	
	resulting_velocity = lerp(curr_right_anim.get_root_velocity(curr_now), curr_left_anim.get_root_velocity(curr_now), curr_direction_blending_percentage)
	
	if is_blending_spectres:
		var prev_now : float = fmod(prev_progress + adjustment_delta, prev_cycle_length)
		var prev_velocity = lerp(prev_right_anim.get_root_velocity(prev_now), prev_left_anim.get_root_velocity(prev_now), prev_direction_blending_percentage)
		return lerp(prev_velocity, resulting_velocity, specters_blending_percentage)
	
	return resulting_velocity