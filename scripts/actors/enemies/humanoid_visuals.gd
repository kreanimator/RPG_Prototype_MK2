extends Node3D
class_name HumanoidVisuals

@onready var model: HumanoidModel

func accept_model(mod: HumanoidModel) -> void:
	model = mod
	for child in get_children():
		if child is MeshInstance3D:
			child.skeleton = model.skeleton.get_path()
