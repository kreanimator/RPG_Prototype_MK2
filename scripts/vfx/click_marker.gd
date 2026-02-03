extends Node3D
class_name ClickMarker

@export var life: float = 0.45
@export var start_scale: float = 0.55
@export var end_scale: float = 1.2
@export var start_alpha: float = 0.9
@export var end_alpha: float = 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

var _t: float = 0.0
var _mat: StandardMaterial3D

func _ready() -> void:
	# Make sure we have a unique material instance
	_mat = (mesh.material_override as StandardMaterial3D)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = _mat
	else:
		_mat = _mat.duplicate() as StandardMaterial3D
		mesh.material_override = _mat

	scale = Vector3.ONE * start_scale
	_set_alpha(start_alpha)

func _process(delta: float) -> void:
	_t += delta
	var u: float = clampf(_t / life, 0.0, 1.0)

	# Smooth nice curve
	var s: float = lerp(start_scale, end_scale, ease(u, 0.2))
	scale = Vector3.ONE * s

	var a: float = lerp(start_alpha, end_alpha, ease(u, 1.5))
	_set_alpha(a)

	if u >= 1.0:
		queue_free()

func _set_alpha(a: float) -> void:
	var c: Color = _mat.albedo_color
	c.a = a
	_mat.albedo_color = c
