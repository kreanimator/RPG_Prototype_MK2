extends Control
class_name PointBody

@onready var filled_icon: CanvasItem = $Filled   # change node path
@onready var spent_icon: CanvasItem = $Spent     # or dim overlay
@onready var enemy_turn: TextureRect = $EnemyTurn

func set_filled(is_filled: bool) -> void:
	filled_icon.visible = is_filled
	spent_icon.visible = not is_filled

func set_enemy_turn(is_enemy_turn: bool) -> void:
	enemy_turn.visible = is_enemy_turn

	# When it's enemy turn: show the overlay and hide the AP fill/spent visuals
	# (so ALL points look like "enemy turn" markers)
	if is_enemy_turn:
		filled_icon.visible = false
		spent_icon.visible = false
