extends GridContainer

@onready var walk_button: Button = %Walk
@onready var run_button: Button = %Run
@onready var crouch_button: Button = %Crouch

var selected_color: Color = Color("#ffff87")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	walk_button.pressed.connect(_on_walk_button_pressed)
	run_button.pressed.connect(_on_run_button_pressed)
	crouch_button.pressed.connect(_on_crouch_button_pressed)


# Move mode handlers
func _on_walk_button_pressed() -> void:
	GameManager.move_mode = GameManager.MoveMode.WALK
	_update_move_mode_buttons()

func _on_run_button_pressed() -> void:
	GameManager.move_mode = GameManager.MoveMode.RUN
	_update_move_mode_buttons()

func _on_crouch_button_pressed() -> void:
	GameManager.move_mode = GameManager.MoveMode.CROUCH
	_update_move_mode_buttons()
	
	
func _update_move_mode_buttons() -> void:
	UiUtils.reset_button_style(walk_button)
	UiUtils.reset_button_style(run_button)
	UiUtils.reset_button_style(crouch_button)

	match GameManager.move_mode:
		GameManager.MoveMode.WALK:
			UiUtils.apply_selected_style(walk_button, selected_color)
		GameManager.MoveMode.RUN:
			UiUtils.apply_selected_style(run_button, selected_color)
		GameManager.MoveMode.CROUCH:
			UiUtils.apply_selected_style(crouch_button, selected_color)
			
