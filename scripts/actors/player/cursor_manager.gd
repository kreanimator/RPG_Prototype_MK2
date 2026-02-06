extends Node3D
class_name CursorUIManager

const MODE_MOVE := 0
const MODE_ATTACK := 1
const MODE_INVESTIGATE := 2
const MODE_INTERACT := 3

const TARGET_POINT_PREFAB := preload("uid://d2dgudxyt8cox")

const INVESTIGATE_ICON_IMAGE := preload("uid://cqcegply4vpah")
const DEFAULT_ICON_IMAGE := preload("uid://bicbqbvb43he3")
const ATTACK_ICON_IMAGE := preload("uid://mle7kd2qms8b")
const INTERACT_ICON_IMAGE = preload("uid://4oue2xm12exg")

@export var cursor_hotspot: Vector2 = Vector2.ZERO
@export var cursor_shape: int = Input.CURSOR_ARROW
@export var surface_offset: float = 0.02

var _cursor_by_mode: Dictionary = {} # int -> Texture2D
var _current_mode: int = MODE_MOVE

var mouse_interactor: MouseInteractor = null
var _target_point: Node3D = null
var _hover_actor: Node = null # Visual only (highlight/tooltip later)

func _ready() -> void:
	_cursor_by_mode = {
		MODE_MOVE: DEFAULT_ICON_IMAGE,
		MODE_ATTACK: ATTACK_ICON_IMAGE,
		MODE_INVESTIGATE: INVESTIGATE_ICON_IMAGE,
		MODE_INTERACT: INTERACT_ICON_IMAGE
	}
	_apply_cursor(_current_mode)

func bind(interactor: MouseInteractor) -> void:
	mouse_interactor = interactor
	if mouse_interactor == null:
		return

	# Hover does NOT change cursor mode.
	mouse_interactor.hover_changed.connect(_on_hover_changed)
	mouse_interactor.clicked.connect(_on_clicked)

func set_cursor_mode(mode: int) -> void:
	if mode == _current_mode:
		return
	_current_mode = mode
	_apply_cursor(mode)

func _apply_cursor(mode: int) -> void:
	var tex: Texture2D = _cursor_by_mode.get(mode, DEFAULT_ICON_IMAGE)
	Input.set_custom_mouse_cursor(tex, cursor_shape, cursor_hotspot)

# --- Target point (visual marker) ---

func show_target_point(pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	# Only show target point in MOVE mode (as you requested)
	if GameManager.mouse_mode != GameManager.MouseMode.MOVE:
		return

	_ensure_target_point()
	_update_target_point_transform(pos, normal)
	_target_point.visible = true

func hide_target_point() -> void:
	if _target_point:
		_target_point.visible = false

func _ensure_target_point() -> void:
	if _target_point:
		return

	_target_point = TARGET_POINT_PREFAB.instantiate() as Node3D

	var scene := get_tree().current_scene
	if scene:
		scene.add_child(_target_point)
	else:
		get_tree().root.add_child(_target_point)

	_target_point.visible = false

func _update_target_point_transform(pos: Vector3, normal: Vector3) -> void:
	if _target_point == null:
		return

	var up := normal.normalized()
	_target_point.global_position = pos + up * surface_offset

	# Choose a stable forward that isn't parallel to up
	var forward := Vector3.FORWARD
	if abs(up.dot(forward)) > 0.95:
		forward = Vector3.RIGHT

	# Project forward onto plane perpendicular to up to avoid weird roll
	forward = (forward - up * up.dot(forward)).normalized()

	_target_point.global_basis = Basis.looking_at(forward, up)

# --- Hover visuals (no cursor changes) ---

func set_hover_actor(node: Node) -> void:
	if node == _hover_actor:
		return
	_hover_actor = node

func _on_hover_changed(hit: Dictionary) -> void:
	# Only track hovered actor/node for visuals; do not change cursor mode.
	if hit.is_empty():
		set_hover_actor(null)
		return

	var collider: Node = hit.get("collider", null)
	if collider == null:
		set_hover_actor(null)
		return

	var actor := _find_actor(collider)
	set_hover_actor(actor if actor != null else collider)

func _on_clicked(hit: Dictionary) -> void:
	# Optional: show target point if click returned a position.
	if hit.has("position"):
		show_target_point(hit["position"], hit.get("normal", Vector3.UP))

func _find_actor(node: Node) -> Actor:
	var n: Node = node
	while n != null:
		if n is Actor:
			return n as Actor
		n = n.get_parent()
	return null
