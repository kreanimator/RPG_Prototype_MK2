extends Node3D
class_name CursorManager

const MODE_MOVE := 0
const MODE_ATTACK := 1
const MODE_INVESTIGATE := 2

const TARGET_POINT_PREFAB := preload("uid://d2dgudxyt8cox")

const INVESTIGATE_ICON_IMAGE := preload("uid://cqcegply4vpah")
const DEFAULT_ICON_IMAGE := preload("uid://bicbqbvb43he3")
const ATTACK_ICON_IMAGE := preload("uid://mle7kd2qms8b")

@export var cursor_hotspot: Vector2 = Vector2.ZERO
@export var cursor_shape: int = Input.CURSOR_ARROW
@export var surface_offset: float = 0.02

var _cursor_by_mode: Dictionary = {} # int -> Texture2D
var _current_mode: int = MODE_MOVE
var mouse_interactor: MouseInteractor
var _target_point: Node3D = null
var _hover_actor: Node = null # keep it generic; visuals may highlight any Node3D

func _ready() -> void:
	_cursor_by_mode = {
		MODE_MOVE: DEFAULT_ICON_IMAGE,
		MODE_ATTACK: ATTACK_ICON_IMAGE,
		MODE_INVESTIGATE: INVESTIGATE_ICON_IMAGE,
	}
	_apply_cursor(_current_mode)

func bind(interactor: MouseInteractor) -> void:
	mouse_interactor = interactor
	if mouse_interactor:
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
	# Prefer adding to current_scene but fallback to root if needed
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

	# choose a stable forward that isn't parallel to up
	var forward := Vector3.FORWARD
	if abs(up.dot(forward)) > 0.95:
		forward = Vector3.RIGHT

	# project forward onto plane perpendicular to up to avoid weird roll
	forward = (forward - up * up.dot(forward)).normalized()

	_target_point.global_basis = Basis.looking_at(forward, up)

# --- Hover visuals (optional hooks) ---

func set_hover_actor(node: Node) -> void:
	# Visual layer only: store reference; later you can add highlight/outline here.
	if node == _hover_actor:
		return

	# If you add highlight logic later, remove highlight from old hover here.
	_hover_actor = node
	# And apply highlight to new hover here (optional).

func _on_hover_changed(hit: Dictionary) -> void:
	#var prev_mouse_mode: GameManager.MouseMode = GameManager.mouse_mode
	if hit.is_empty():
		set_hover_actor(null)
		set_cursor_mode(MODE_MOVE)
		return

	var collider: Node = hit.get("collider", null)
	if collider == null:
		set_hover_actor(null)
		set_cursor_mode(MODE_MOVE)
		return

	# Raycast often hits a child node; find the Actor up the tree
	var actor = _find_actor(collider)

	set_hover_actor(actor if actor != null else collider)

	if actor == null:
		set_cursor_mode(MODE_MOVE)
		return

	# Compare vs player (requester)
	var player_actor := get_tree().get_first_node_in_group("player") as Actor
	if player_actor != null and actor.is_hostile_to(player_actor):
		set_cursor_mode(MODE_ATTACK)
		#GameManager.mouse_mode = GameManager.MouseMode.ATTACK
	else:
		# non-hostile actor: investigate (or move, your choice)
		set_cursor_mode(MODE_INVESTIGATE)
		#GameManager.mouse_mode = GameManager.MouseMode.INVESTIGATE
		
	#GameManager.mouse_mode = prev_mouse_mode

func _on_clicked(hit: Dictionary) -> void:
	if hit.has("position"):
		show_target_point(hit["position"], hit.get("normal", Vector3.UP))

func _find_actor(node: Node) -> Actor:
	var n: Node = node
	while n != null:
		if n is Actor:
			return n as Actor
		n = n.get_parent()
	return null
	
