extends Node


func apply_selected_style(btn: Button, color: Color) -> void:
	btn.add_theme_color_override("font_color", color)
	btn.modulate = color

func reset_button_style(btn: Button) -> void:
	btn.remove_theme_color_override("font_color")
	btn.modulate = Color(1, 1, 1, 1)
