extends HBoxContainer

@onready var hotbar_one: Button = %HotbarOne
@onready var hotbar_two: Button = %HotbarTwo
@onready var hotbar_three: Button = %HotbarThree

func _ready() -> void:
	hotbar_one.pressed.connect(_on_hotbar_one_pressed)
	hotbar_two.pressed.connect(_on_hotbar_two_pressed)
	hotbar_three.pressed.connect(_on_hotbar_three_pressed)


func _on_hotbar_one_pressed() -> void:
	pass
func _on_hotbar_two_pressed() -> void:
	pass
func _on_hotbar_three_pressed() -> void:
	pass
