extends Node3D
class_name PlayerAim

#### FIXME: It is very rude implementation,
#### we should replace it to separate action later with proper animations etc 

@export var turn_speed: float = 12.0      # higher = snappier (lerp style)
@export var use_tween: bool = false       # set true if you prefer tween rotation
@export var tween_duration: float = 0.15
@export var face_epsilon_deg: float = 3.0 # consider "facing" when within this angle

var player: Player

var _has_target: bool = false
var _target_world: Vector3 = Vector3.ZERO
var _tween: Tween = null


func _process(delta: float) -> void:
	if player == null:
		return
	if not _has_target:
		return

	if use_tween:
		# tween handles rotation; nothing to do here
		return

	# Smooth rotate (frame-based)
	_rotate_player_towards(_target_world, delta)


# -------------------------
# Public API
# -------------------------

func clear_target() -> void:
	_has_target = false
	_kill_tween()


func set_target_world_pos(world_pos: Vector3, start_turn: bool = true) -> void:
	_target_world = world_pos
	_has_target = true

	if start_turn:
		turn_to_target()


func set_target_node(node: Node3D, start_turn: bool = true) -> void:
	if node == null or not is_instance_valid(node):
		clear_target()
		return
	set_target_world_pos(node.global_position, start_turn)


func turn_to_target() -> void:
	if player == null or not _has_target:
		return

	if use_tween:
		_turn_with_tween(_target_world)
	# if not tween, _process() will rotate continuously


func is_facing_target() -> bool:
	if player == null or not _has_target:
		return true

	var to_t := _target_world - player.global_position
	to_t.y = 0.0
	if to_t.length_squared() < 0.0001:
		return true

	var desired_yaw := atan2(to_t.x, to_t.z)
	var cur_yaw := player.global_rotation.y
	var diff = abs(rad_to_deg(wrapf(desired_yaw - cur_yaw, -PI, PI)))
	return diff <= face_epsilon_deg


func get_target_world_pos() -> Vector3:
	return _target_world


# -------------------------
# Internals
# -------------------------

func _rotate_player_towards(world_pos: Vector3, delta: float) -> void:
	var to_t := world_pos - player.global_position
	to_t.y = 0.0
	if to_t.length_squared() < 0.0001:
		return

	var desired_yaw := atan2(to_t.x, to_t.z)
	var t := 1.0 - exp(-turn_speed * delta) # stable smoothing
	player.global_rotation.y = lerp_angle(player.global_rotation.y, desired_yaw, t)


func _turn_with_tween(world_pos: Vector3) -> void:
	_kill_tween()

	var to_t := world_pos - player.global_position
	to_t.y = 0.0
	if to_t.length_squared() < 0.0001:
		return

	var desired_yaw := atan2(to_t.x, to_t.z)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(player, "global_rotation:y", desired_yaw, tween_duration)


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
