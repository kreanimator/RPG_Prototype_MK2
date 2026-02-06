extends Node3D

@export var move_distance: float = 3.0   # how far to move from start
@export var move_duration: float = 1.5   # time to move one side

var is_moving: bool = false
var _tween: Tween
var _start_position: Vector3


func _ready() -> void:
	_start_position = global_position


func toggle_movement() -> void:
	if is_moving:
		stop_movement()
	else:
		start_movement()


func start_movement() -> void:
	if is_moving:
		return

	is_moving = true
	_tween = create_tween()
	_tween.set_loops() # infinite loop

	var left_pos = _start_position + Vector3(0, 0, -move_distance)
	var right_pos = _start_position + Vector3(0, 0, move_distance)

	_tween.tween_property(self, "global_position", right_pos, move_duration)
	_tween.tween_property(self, "global_position", left_pos, move_duration)


func stop_movement() -> void:
	if not is_moving:
		return

	is_moving = false

	if _tween:
		_tween.kill()
		_tween = null
