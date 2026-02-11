extends Node3D

@export var expand_duration: float = 0.6

# Desired bridge length in meters (Godot units)
@export var extended_length_m: float = 10.0
@export var retracted_length_m: float = 0.3

# If true: collision only solid when fully extended
@export var collision_only_when_extended: bool = true

# Optional: AI navigation region to enable when extended
@export var nav_region_path: NodePath

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var nav_region: NavigationRegion3D = $"../NavigationRegion3D"

var is_moving: bool = false
var _tween: Tween

var _base_mesh_scale: Vector3
var _base_mesh_len_z: float = 1.0  # meters, computed from mesh AABB
var _base_box_size: Vector3
var _has_box := false

func _ready() -> void:
	_base_mesh_scale = mesh.scale
	# Compute mesh length (local AABB * current scale)
	var aabb := mesh.get_aabb()
	_base_mesh_len_z = max(0.001, aabb.size.z * _base_mesh_scale.z)

	# Cache collider shape info (optional: resize collider with bridge)
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

	# Collision behavior
	if collision_only_when_extended:
		collider.disabled = true
	else:
		collider.disabled = false
#
	## Navigation behavior (AI)
	#if nav_region:
		#nav_region.enabled = false  # disable during animation to avoid odd paths

	var target_len := extended_length_m if extend else retracted_length_m

	# Scale mesh to reach target length in meters
	var target_scale := _base_mesh_scale
	target_scale.z = max(0.001, target_len / (mesh.get_aabb().size.z * _base_mesh_scale.z)) * _base_mesh_scale.z
	# The above line can be simplified, but kept explicit.

	# Better: compute factor from cached base length
	target_scale = _base_mesh_scale
	target_scale.z = max(0.001, target_len / _base_mesh_len_z) * _base_mesh_scale.z

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_property(mesh, "scale", target_scale, expand_duration)

	# Optional: resize box collider to match length
	if _has_box:
		var box := collider.shape as BoxShape3D
		var target_box := _base_box_size
		target_box.z = target_len
		_tween.tween_property(box, "size", target_box, expand_duration)

	_tween.finished.connect(func():
		if collision_only_when_extended:
			collider.disabled = not extend

		if nav_region:
			nav_region.enabled = extend
	)

func _apply_state_immediate(extend: bool) -> void:
	var target_len := extended_length_m if extend else retracted_length_m

	var s := _base_mesh_scale
	s.z = max(0.001, target_len / _base_mesh_len_z) * _base_mesh_scale.z
	mesh.scale = s

	if _has_box:
		var box := collider.shape as BoxShape3D
		var b := _base_box_size
		b.z = target_len
		box.size = b

	collider.disabled = not extend

	if nav_region:
		nav_region.enabled = extend
