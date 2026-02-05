extends Node
class_name InputPackage

var actions : Array[String] = []
var combat_actions : Array[String] = []
var aim_actions : Array[String] = []
var input_direction: Vector2 = Vector2.ZERO
var click_world_pos : Vector3 = Vector3.ZERO
var click_surface_rotation: Vector3 = Vector3.ZERO
var has_click_world_pos : bool = false
var behaviour_names : Array[String] = []
