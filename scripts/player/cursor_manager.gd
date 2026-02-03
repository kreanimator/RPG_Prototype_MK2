extends Node3D
class_name CursorManager

const target_point_prefab = preload("uid://d2dgudxyt8cox")

const INVESTIGATE_ICON_IMAGE = preload("uid://cqcegply4vpah")
const DEFAULT_ICON_IMAGE = preload("uid://bicbqbvb43he3")
const ATTACK_ICON_IMAGE = preload("uid://mle7kd2qms8b")

@export var cursor_hotspot := Vector2.ZERO

var _cursor_by_mode := {} # Dictionary<int, Texture2D>

func _ready() -> void:
	# IMPORTANT: use the same numeric values as your InputCollector.MouseMode enum
	# MOVE=0, ATTACK=1, INVESTIGATE=2
	_cursor_by_mode = {
		0: DEFAULT_ICON_IMAGE,
		1: ATTACK_ICON_IMAGE,
		2: INVESTIGATE_ICON_IMAGE,
	}
	apply_cursor(0) # default

func set_cursor_mode(mode: int) -> void:
	apply_cursor(mode)

func apply_cursor(mode: int) -> void:
	var tex: Texture2D = _cursor_by_mode.get(mode, DEFAULT_ICON_IMAGE)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, cursor_hotspot)

func set_target_point(pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	var target_point = target_point_prefab.instantiate()
	get_tree().current_scene.add_child(target_point)

	var up := normal.normalized()

	# push a tiny bit off the surface to avoid z-fighting
	target_point.global_position = pos + up * 0.02

	# choose a stable forward that isn't parallel to up
	var forward := Vector3.FORWARD
	if abs(up.dot(forward)) > 0.95:
		forward = Vector3.RIGHT

	target_point.global_basis = Basis().looking_at(forward, up)
