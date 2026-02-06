extends Control
class_name PointBody

@onready var filled_icon: CanvasItem = $Filled   # change node path
@onready var spent_icon: CanvasItem = $Spent     # or dim overlay

func set_filled(is_filled: bool) -> void:
	if filled_icon:
		filled_icon.visible = is_filled
	if spent_icon:
		spent_icon.visible = not is_filled
