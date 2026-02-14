extends Control
class_name UIController

@onready var walk_button: Button = %Walk
@onready var run_button: Button = %Run
@onready var crouch_button: Button = %Crouch
@onready var turn_button: Button = %Turn
@onready var combat_button: Button = %Combat
@onready var ap_container: HBoxContainer = $APcontainer
@onready var unarmed_toggle_debug: Button = $UnarmedToggleDebug

const POINT_BODY := preload("uid://c83iqwhaadj3n")

var resources: PlayerResources = null

func _ready() -> void:
	walk_button.pressed.connect(_on_walk_button_pressed)
	run_button.pressed.connect(_on_run_button_pressed)
	crouch_button.pressed.connect(_on_crouch_button_pressed)
	turn_button.pressed.connect(_on_turn_button_pressed)
	combat_button.pressed.connect(_on_combat_button_pressed)
	unarmed_toggle_debug.pressed.connect(_on_toggle_debug_pressed)
	
	_update_combat_button()
	
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)

func set_player_resources(res: PlayerResources) -> void:
	# Disconnect old if needed (prevents double connects)
	if resources != null and resources.is_connected("action_points_changed", Callable(self, "_on_action_points_changed")):
		resources.action_points_changed.disconnect(Callable(self, "_on_action_points_changed"))

	resources = res

	if resources == null:
		push_warning("UIController: set_player_resources got null")
		return

	# Auto-update AP UI on change
	if resources.has_signal("action_points_changed"):
		resources.action_points_changed.connect(_on_action_points_changed)

	# Initial draw
	update_ap_ui()
	update_toggle_debug_button()

func _on_action_points_changed(_ap: int, _max_ap: int) -> void:
	update_ap_ui()

func _on_walk_button_pressed() -> void:
	GameManager.move_mode = GameManager.MoveMode.WALK

func _on_run_button_pressed() -> void:
	GameManager.move_mode = GameManager.MoveMode.RUN

func _on_crouch_button_pressed() -> void:
	GameManager.move_mode = GameManager.MoveMode.CROUCH

func _on_turn_button_pressed() -> void:
	print("Finishing turn!!")

func _on_combat_button_pressed() -> void:
	GameManager.toggle_combat("ui_button")
	_update_combat_button()

func _on_game_state_changed(_new_state: int, _reason: String) -> void:
	_update_combat_button()
	# If exiting combat restores AP, redraw
	update_ap_ui()

func _update_combat_button() -> void:
	if GameManager.game_state == GameManager.GameState.COMBAT:
		combat_button.text = "Exit Combat"
	else:
		combat_button.text = "Enter Combat"

func _on_toggle_debug_pressed() -> void:
	var stats_manager = resources.stats_manager
	if stats_manager.current_unarmed_action == stats_manager.CurrentUnarmedAction.PUNCH:
		stats_manager.set_unarmed_action(resources.stats_manager.CurrentUnarmedAction.KICK)
	else:
		stats_manager.set_unarmed_action(resources.stats_manager.CurrentUnarmedAction.PUNCH)
	update_toggle_debug_button()
	
func update_toggle_debug_button() -> void:
	var btn_text = resources.stats_manager.get_unarmed_action_key()
	unarmed_toggle_debug.text = btn_text

func update_ap_ui() -> void:
	if resources == null:
		# Not bound yet; avoid spam
		return

	var ap: int = resources.action_points
	var max_ap: int = resources.max_action_points

	print("AP UI: max_ap=%d ap=%d" % [max_ap, ap])

	# Clear old points
	for child in ap_container.get_children():
		child.queue_free()

	# Create max AP points and mark filled/unfilled
	for i in range(max_ap):
		var point := POINT_BODY.instantiate()
		ap_container.add_child(point)

		var filled := i < ap

		if point.has_method("set_filled"):
			point.call("set_filled", filled)
		elif point.has_method("set_spent"):
			point.call("set_spent", not filled)
		else:
			# Better fallback than hiding: dim spent points
			point.modulate.a = 1.0 if filled else 0.25
