extends Node3D

@export var expand_duration: float = 0.6

# Desired bridge length in meters (Godot units) along expand_axis
@export var extended_length_m: float = 10.0
@export var retracted_length_m: float = 0.3

# Bridge expands from its "start" (anchored) towards expand_axis direction.
# For your case use Vector3(1,0,0) (local +X). Flip to (-1,0,0) if needed.
@export var expand_axis: Vector3 = Vector3(1, 0, 0)

# If true: collision only solid when fully extended (only applies to optional collider)
@export var collision_only_when_extended: bool = true

# Navigation
@export var nav_region_path: NodePath
@export var rebake_nav_on_update: bool = true
@export var rebake_delay_sec: float = 0.05

# CSG bridge (visual + can provide collision if enabled)
@onready var csg_box_3d: CSGBox3D = $CSGBox3D

# Optional separate collider (recommended if you want explicit control)
@onready var collider: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

@onready var nav_region: NavigationRegion3D = _resolve_nav_region()

var is_moving: bool = false
var _tween: Tween
var _rebake_timer: SceneTreeTimer = null

var _base_csg_size: Vector3
var _base_csg_pos: Vector3
var _base_collider_pos: Vector3

var _has_box := false
var _base_box_size: Vector3

func _ready() -> void:
	expand_axis = _safe_axis(expand_axis)

	_base_csg_size = csg_box_3d.size          # e.g. (3, 0.5, 4)
	_base_csg_pos = csg_box_3d.position

	if collider:
		_base_collider_pos = collider.position
		var box := collider.shape as BoxShape3D
		if box:
			_has_box = true
			_base_box_size = box.size

	_apply_state_immediate(false)

func toggle_movement() -> void:
	if is_moving:
		stop_movement()
	else:
		start_movement()

# START = extend (bridge ON)
func start_movement() -> void:
	if is_moving:
		return
	is_moving = true
	_animate_to(true)

# STOP = retract (bridge OFF)
func stop_movement() -> void:
	if not is_moving:
		return
	is_moving = false
	_animate_to(false)

func _animate_to(extend: bool) -> void:
	if _tween:
		_tween.kill()
		_tween = null

	# Collision behavior (only if you have a separate CollisionShape3D)
	if collider:
		collider.disabled = collision_only_when_extended

	var target_len := extended_length_m if extend else retracted_length_m

	# Update CSG size only along axis, keep other dims (your base y=0.5, z=4)
	var target_size := _base_csg_size
	target_size = _set_axis_component(target_size, target_len)

	# Offset CSG position so start edge stays anchored while it grows from center
	var target_pos := _base_csg_pos + (expand_axis * (target_len * 0.5))

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(csg_box_3d, "size", target_size, expand_duration)
	_tween.parallel().tween_property(csg_box_3d, "position", target_pos, expand_duration)

	# Optional: match separate collider size + position to the bridge
	if collider:
		_tween.parallel().tween_property(collider, "position", _base_collider_pos + (expand_axis * (target_len * 0.5)), expand_duration)
		if _has_box:
			var box := collider.shape as BoxShape3D
			var target_box := _base_box_size
			target_box = _set_axis_component(target_box, target_len)
			_tween.parallel().tween_property(box, "size", target_box, expand_duration)

	_tween.finished.connect(func():
		if collider and collision_only_when_extended:
			collider.disabled = not extend

		_request_nav_rebake()
	)

func _apply_state_immediate(extend: bool) -> void:
	var target_len := extended_length_m if extend else retracted_length_m

	var s := _base_csg_size
	s = _set_axis_component(s, target_len)
	csg_box_3d.size = s
	csg_box_3d.position = _base_csg_pos + (expand_axis * (target_len * 0.5))

	if collider:
		collider.position = _base_collider_pos + (expand_axis * (target_len * 0.5))

		if _has_box:
			var box := collider.shape as BoxShape3D
			var b := _base_box_size
			b = _set_axis_component(b, target_len)
			box.size = b

		collider.disabled = not extend if collision_only_when_extended else false

	_request_nav_rebake()

func _request_nav_rebake() -> void:
	if not rebake_nav_on_update:
		return
	if nav_region == null:
		return
	if not is_inside_tree():
		return

	_rebake_timer = get_tree().create_timer(rebake_delay_sec)
	_rebake_timer.timeout.connect(func():
		_rebake_timer = null
		if nav_region.has_method("bake_navigation_mesh"):
			print("Baking new navmesh")
			nav_region.bake_navigation_mesh()
		else:
			push_warning("NavigationRegion3D has no bake_navigation_mesh() in this Godot version.")
	)

func _resolve_nav_region() -> NavigationRegion3D:
	if nav_region_path != NodePath():
		var n := get_node_or_null(nav_region_path)
		if n is NavigationRegion3D:
			return n as NavigationRegion3D

	var fallback := get_node_or_null("../NavigationRegion3D")
	if fallback is NavigationRegion3D:
		return fallback as NavigationRegion3D

	return null

# -----------------------
# Helpers
# -----------------------

func _safe_axis(a: Vector3) -> Vector3:
	if a.length() < 0.001:
		return Vector3(1, 0, 0)
	return a.normalized()

func _set_axis_component(v: Vector3, value: float) -> Vector3:
	value = max(0.001, value)
	# Pick dominant axis component (X/Y/Z)
	if abs(expand_axis.x) >= abs(expand_axis.y) and abs(expand_axis.x) >= abs(expand_axis.z):
		v.x = value
	elif abs(expand_axis.y) >= abs(expand_axis.x) and abs(expand_axis.y) >= abs(expand_axis.z):
		v.y = value
	else:
		v.z = value
	return v
