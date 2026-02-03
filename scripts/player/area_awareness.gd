extends Node
class_name AreaAwareness

var last_pushback_vector : Vector3
var last_input_package : InputPackage

@onready var downcast = $Downcast as RayCast3D

var floor_distance : float 

func contextualize(new_input : InputPackage) -> InputPackage:
	floor_distance = get_floor_distance()
	if floor_distance > 1.1:
		new_input.actions.append("midair")
	last_input_package = new_input
	return new_input

func get_floor_distance() -> float:
	if downcast.is_colliding():
		return downcast.global_position.distance_to(downcast.get_collision_point())
	return 999999
