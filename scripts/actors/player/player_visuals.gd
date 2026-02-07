extends Node3D
class_name PlayerVisuals

@onready var model: PlayerModel
@onready var cursor_manager: CursorUIManager = $CursorUIManager
@onready var mouse_debug_overlay: MouseDebugOverlay = $UI/MouseDebugOverlay
@onready var ui_controller: UIController = $UI/UIController


func accept_model(_model: PlayerModel) -> void:
	model = _model

	# Bind skeleton for MeshInstance3D children
	for child in get_children():
		if child is MeshInstance3D:
			child.skeleton = _model.skeleton.get_path()

	# Pass resources to UI (deferred = safe init order)
	call_deferred("_bind_ui_resources")

func _bind_ui_resources() -> void:
	if ui_controller == null:
		push_warning("PlayerVisuals: UIController not found")
		return
	if model == null:
		push_warning("PlayerVisuals: model is null")
		return

	# IMPORTANT: use the correct property name on your PlayerModel
	# You mentioned: model.player_resources
	var res: PlayerResources = model.resources
	if res == null:
		push_warning("PlayerVisuals: model.player_resources is null")
		return

	ui_controller.set_player_resources(res)
