extends Node3D
class_name MouseInteractor

signal hover_changed(hit_info: Dictionary) # {} when nothing hit
signal clicked(hit_info: Dictionary)

@export var ground_mask: int = 1
@export var actor_mask: int = 2
@export var interactable_mask: int = 5

@export var max_dist: float = 1000.0

@onready var player: Player = $".."

var _last_hover_id: int = 0

func _process(_delta: float) -> void:
	if Utils.is_mouse_over_gui():
		return

	var cam: Camera3D = player.camera_node.cam
	if cam == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var hit := _raycast_best(mouse_pos, cam)

	var id := 0
	if not hit.is_empty() and hit.has("collider"):
		id = hit["collider"].get_instance_id()

	# Emit only when changed (reduces spam)
	if id != _last_hover_id:
		_last_hover_id = id
		hover_changed.emit(hit)

func _input(event: InputEvent) -> void:
	if Utils.is_mouse_over_gui():
		return

	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		var cam: Camera3D = player.camera_node.cam
		if cam == null:
			return

		var hit := _raycast_best(event.position, cam)
		if not hit.is_empty():
			clicked.emit(hit)

func _raycast_best(mouse_pos: Vector2, cam: Camera3D) -> Dictionary:
	# Priority: ACTOR > INTERACTABLE > GROUND
	var hit := _raycast(mouse_pos, cam, actor_mask)
	if not hit.is_empty():
		return hit

	hit = _raycast(mouse_pos, cam, interactable_mask)
	if not hit.is_empty():
		return hit

	hit = _raycast(mouse_pos, cam, ground_mask)
	return hit

func _raycast(mouse_pos: Vector2, cam: Camera3D, mask: int) -> Dictionary:
	if mask == 0:
		return {}

	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * max_dist

	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = mask

	var space_state := get_world_3d().direct_space_state
	var result := space_state.intersect_ray(query)

	return result if result.size() > 0 else {}
