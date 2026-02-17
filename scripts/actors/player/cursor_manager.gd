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

var _target_point: Node3D = null
var _hover_actor: Node = null # Visual only (highlight/tooltip later)

# Hit chance display
var _hit_chance_label: Label = null
var _player_model: PlayerModel = null

func _ready() -> void:
	_cursor_by_mode = {
		MODE_MOVE: DEFAULT_ICON_IMAGE,
		MODE_ATTACK: ATTACK_ICON_IMAGE,
		MODE_INVESTIGATE: INVESTIGATE_ICON_IMAGE,
		MODE_INTERACT: INTERACT_ICON_IMAGE
	}
	_apply_cursor(_current_mode)
	_create_hit_chance_label()


func set_player_model(model: PlayerModel) -> void:
	_player_model = model


func _create_hit_chance_label() -> void:
	# Find UI container (same parent as MouseDebugOverlay)
	var player_visuals := get_parent() as PlayerVisuals
	if player_visuals == null:
		return
	
	var ui_container := player_visuals.get_node_or_null("UI")
	if ui_container == null:
		# Fallback: add to root
		ui_container = get_tree().root
	
	_hit_chance_label = Label.new()
	_hit_chance_label.name = "HitChanceLabel"
	_hit_chance_label.text = ""
	_hit_chance_label.modulate = Color(1, 0.8, 0)  # Orange/yellow text
	_hit_chance_label.add_theme_font_size_override("font_size", 18)
	_hit_chance_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hit_chance_label.add_theme_constant_override("shadow_offset_x", 1)
	_hit_chance_label.add_theme_constant_override("shadow_offset_y", 1)
	_hit_chance_label.visible = false
	_hit_chance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input
	
	ui_container.add_child(_hit_chance_label)


func _process(_delta: float) -> void:
	if _hit_chance_label == null:
		return
	
	# Update label position to follow mouse
	var mouse_pos := get_viewport().get_mouse_position()
	_hit_chance_label.position = mouse_pos + Vector2(20, -30)
	
	# Continuously update hit chance when hovering over actors in attack mode
	if GameManager.mouse_mode == GameManager.MouseMode.ATTACK:
		_update_hit_chance_for_hovered_actor()

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
		_update_hit_chance_display(null)
		return

	var collider: Node = hit.get("collider", null)
	if collider == null:
		set_hover_actor(null)
		_update_hit_chance_display(null)
		return

	var actor := _find_actor(collider)
	set_hover_actor(actor if actor != null else collider)
	_update_hit_chance_display(actor)

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


func _update_hit_chance_display(target_actor: Actor) -> void:
	if _hit_chance_label == null:
		return
	
	# Only show in attack mode
	if GameManager.mouse_mode != GameManager.MouseMode.ATTACK:
		_hit_chance_label.visible = false
		return
	
	# Need player model to get weapon
	if _player_model == null:
		_hit_chance_label.visible = false
		return
	
	# Only show for enemy actors
	if target_actor == null or not target_actor is Actor:
		_hit_chance_label.visible = false
		return
	
	# Check if it's an enemy (different faction or not player)
	var player := get_tree().get_first_node_in_group("player") as Player
	if target_actor == player:
		_hit_chance_label.visible = false
		return
	
	# Get current weapon
	var weapon: Weapon = null
	if _player_model.equipment_manager != null:
		weapon = _player_model.equipment_manager.current_weapon
	
	# Calculate hit chance
	var hit_chance := CombatCalculator.calculate_hit_chance(player, target_actor, weapon)
	
	# Update label
	_hit_chance_label.text = "Hit Chance: %d%%" % hit_chance
	_hit_chance_label.visible = true


func _update_hit_chance_for_hovered_actor() -> void:
	# Update based on currently hovered actor
	if _hover_actor != null and _hover_actor is Actor:
		_update_hit_chance_display(_hover_actor as Actor)
	else:
		# Try to raycast to find actor under cursor
		var mouse_pos := get_viewport().get_mouse_position()
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		
		var from := camera.project_ray_origin(mouse_pos)
		var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1 << 1  # MASK_ACTOR
		
		var result := space_state.intersect_ray(query)
		if result:
			var actor := _find_actor(result.get("collider"))
			if actor != null:
				_update_hit_chance_display(actor)
			else:
				_hit_chance_label.visible = false
		else:
			_hit_chance_label.visible = false
