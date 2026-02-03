extends Node3D
class_name SimpleIsoCameraRig

@export var target_path: NodePath

# Fallout-ish iso tuning
@export var yaw_deg: float = 45.0
@export var pitch_deg: float = 58.0   # positive = tilt down in this script (we apply it via math)
@export var height: float = 16.0
@export var distance: float = 18.0

# Follow smoothing (higher = snappier)
@export var follow_smoothness: float = 8.0

# Optional zoom
@export var enable_zoom: bool = true
@export var zoom_step: float = 2.0
@export var min_distance: float = 12.0
@export var max_distance: float = 26.0
@export var height_to_distance_ratio: float = 0.9

@export var fov: float = 40.0

@onready var cam: Camera3D = $Camera
var target: Node3D = null


func _ready() -> void:
	_resolve_target()

	if cam:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = fov
		cam.current = true

	# Snap immediately so it doesn't "fly in"
	_update_camera(1.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if not enable_zoom:
		return

	if event.is_action_pressed("camera_zoom_in"):
		_apply_zoom(-zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_apply_zoom(zoom_step)


func _physics_process(delta: float) -> void:
	_update_camera(delta, false)


# ============================================================
# Internals
# ============================================================

func _resolve_target() -> void:
	if target_path == NodePath():
		target = null
		return
	target = get_node_or_null(target_path) as Node3D
	if target == null:
		push_warning("SimpleIsoCameraRig: target_path is not a Node3D (or not found).")


func _update_camera(delta: float, snap: bool) -> void:
	if target == null or not is_instance_valid(target):
		_resolve_target()
		if target == null:
			return

	var target_pos: Vector3 = target.global_position

	# Compute a "back" direction from yaw (world-space)
	var yaw_rad: float = deg_to_rad(yaw_deg)
	var back_dir: Vector3 = Vector3(-cos(yaw_rad), 0.0, -sin(yaw_rad)).normalized()

	# Desired camera position (world-space)
	var desired_cam_pos: Vector3 = target_pos \
		+ Vector3.UP * height \
		+ back_dir * distance
	# Smooth the camera position
	if snap:
		cam.global_position = desired_cam_pos
	else:
		var t: float = 1.0 - exp(-follow_smoothness * delta)
		cam.global_position = cam.global_position.lerp(desired_cam_pos, t)

	# Always look at target (this is what keeps it centered)
	# This also avoids all that pivot math confusion.
	cam.look_at(target_pos, Vector3.UP)


func _apply_zoom(delta_dist: float) -> void:
	var new_dist: float = clampf(distance + delta_dist, min_distance, max_distance)
	var dist_change: float = new_dist - distance

	distance = new_dist
	height += dist_change * height_to_distance_ratio
	cam.far = max(distance * 1.3, 120.0)
