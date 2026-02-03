extends Resource
class_name BoneTrackMap

# this bullshit doesn't work if you don't export the variable ¯\_(ツ)_/¯
@export var map : Dictionary

func get_pos_track(bone : int) -> int:
	return map[bone][&"pos"]

func get_rot_track(bone : int) -> int:
	return map[bone][&"rot"]



static func bake(skeleton : Skeleton3D, animation : Animation, exit_path : String):
	var new_map : BoneTrackMap = BoneTrackMap.new()
	new_map.map = {}
	for bone in skeleton.get_bone_count():
		new_map.map[bone] = {}
		new_map.map[bone][&"pos"] = animation.find_track(bone_to_track_name(skeleton, bone),Animation.TYPE_POSITION_3D)
		new_map.map[bone][&"rot"] = animation.find_track(bone_to_track_name(skeleton, bone),Animation.TYPE_ROTATION_3D)
	print(new_map.map)
	ResourceSaver.save(new_map, exit_path)

static func bone_to_track_name(skeleton : Skeleton3D, bone_index : int) -> String:
	return "%GeneralSkeleton:" + skeleton.get_bone_name(bone_index)
