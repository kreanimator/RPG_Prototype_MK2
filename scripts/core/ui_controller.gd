extends Control
class_name UIController

@onready var walk_button: Button = %Walk
@onready var run_button: Button = %Run
@onready var crouch_button: Button = %Crouch



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	walk_button.pressed.connect(_on_walk_button_pressed)
	run_button.pressed.connect(_on_run_button_pressed)
	crouch_button.pressed.connect(_on_crouch_button_pressed)
	
func _on_walk_button_pressed():
	print("Changing move mode to walk!")
	GameManager.move_mode = GameManager.MoveMode.WALK
	
func _on_run_button_pressed(): 
	print("Changing move mode to run!")
	GameManager.move_mode = GameManager.MoveMode.RUN
	
func _on_crouch_button_pressed(): 
	print("Changing move mode to crouch!")
	GameManager.move_mode = GameManager.MoveMode.CROUCH
