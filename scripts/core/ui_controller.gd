extends Control
class_name UIController

@onready var walk_button: Button = %Walk
@onready var run_button: Button = %Run
@onready var crouch_button: Button = %Crouch

@onready var turn_button: Button = %Turn
@onready var combat_button: Button = %Combat
@onready var skills_button: Button = %Skills

@onready var ap_container: HBoxContainer = %APcontainer
@onready var armor_label: Label = %ArmorLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var health_display: Label = %HealthDisplay

# Weapon buttons (for now: both duplicate unarmed toggle)
@onready var weapon_one: Button = %WeaponOne
@onready var weapon_two: Button = %WeaponTwo

@onready var weapon_one_ap: Label = %WeaponOne/APCost
@onready var weapon_one_action: Label = %WeaponOne/UnarmedAction

@onready var weapon_two_ap: Label = %WeaponTwo/APCost
@onready var weapon_two_action: Label = %WeaponTwo/UnarmedAction

# Hotbar placeholders
@onready var hotbar_one: Button = %HotbarOne
@onready var hotbar_two: Button = %HotbarTwo
@onready var hotbar_three: Button = %HotbarThree


const POINT_BODY := preload("uid://c83iqwhaadj3n")
var selected_color: Color = Color("#ffff87")

var resources: PlayerResources = null


func _ready() -> void:
	_connect_buttons()

	_update_combat_button()
	_update_move_mode_buttons()

	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)


func set_player_resources(res: PlayerResources) -> void:
	_disconnect_resources()

	resources = res
	resources.action_points_changed.connect(_on_action_points_changed)

	update_ap_ui()
	_update_health_ui()
	_update_armor_ui()
	_update_weapon_buttons_ui()


# -------------------------
# Connections
# -------------------------

func _connect_buttons() -> void:
	# Move modes
	walk_button.pressed.connect(_on_walk_button_pressed)
	run_button.pressed.connect(_on_run_button_pressed)
	crouch_button.pressed.connect(_on_crouch_button_pressed)

	# Core UI
	turn_button.pressed.connect(_on_turn_button_pressed)
	combat_button.pressed.connect(_on_combat_button_pressed)
	skills_button.pressed.connect(_on_skills_button_pressed)

	# Weapons (for now: duplicate unarmed toggle)
	weapon_one.pressed.connect(_on_weapon_one_pressed)
	weapon_two.pressed.connect(_on_weapon_two_pressed)

	# Hotbar placeholders
	hotbar_one.pressed.connect(_on_hotbar_one_pressed)
	hotbar_two.pressed.connect(_on_hotbar_two_pressed)
	hotbar_three.pressed.connect(_on_hotbar_three_pressed)

func _disconnect_resources() -> void:
	if resources == null:
		return
	if resources.has_signal("action_points_changed") and resources.is_connected("action_points_changed", Callable(self, "_on_action_points_changed")):
		resources.action_points_changed.disconnect(Callable(self, "_on_action_points_changed"))


# -------------------------
# Signals / Handlers
# -------------------------

func _on_action_points_changed(_ap: int, _max_ap: int) -> void:
	update_ap_ui()
	_update_weapon_buttons_ui()


func _on_game_state_changed(_new_state: int, _reason: String) -> void:
	_update_combat_button()
	update_ap_ui()
	_update_weapon_buttons_ui()


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


# Core button placeholders
func _on_turn_button_pressed() -> void:
	# TODO: hook into turn system
	print("Finishing turn!!")

func _on_combat_button_pressed() -> void:
	GameManager.toggle_combat("ui_button")
	_update_combat_button()
	update_ap_ui()
	_update_weapon_buttons_ui()

func _on_skills_button_pressed() -> void:
	# TODO: open skills UI
	print("Open Skills (TODO)")


# Weapons: for now both do the same as old unarmed toggle
func _on_weapon_one_pressed() -> void:
	_on_unarmed_toggle_pressed()

func _on_weapon_two_pressed() -> void:
	_on_unarmed_toggle_pressed()

func _on_unarmed_toggle_pressed() -> void:
	var sm: StatsManager = resources.stats_manager
	if sm.current_unarmed_action == sm.CurrentUnarmedAction.PUNCH:
		sm.set_unarmed_action(sm.CurrentUnarmedAction.KICK)
	else:
		sm.set_unarmed_action(sm.CurrentUnarmedAction.PUNCH)

	_update_weapon_buttons_ui()


# Hotbar placeholders
func _on_hotbar_one_pressed() -> void:
	print("Hotbar 1 pressed (TODO)")

func _on_hotbar_two_pressed() -> void:
	print("Hotbar 2 pressed (TODO)")

func _on_hotbar_three_pressed() -> void:
	print("Hotbar 3 pressed (TODO)")


# -------------------------
# UI Updates
# -------------------------

func _update_move_mode_buttons() -> void:
	_reset_button_style(walk_button)
	_reset_button_style(run_button)
	_reset_button_style(crouch_button)

	match GameManager.move_mode:
		GameManager.MoveMode.WALK:
			_apply_selected_style(walk_button)
		GameManager.MoveMode.RUN:
			_apply_selected_style(run_button)
		GameManager.MoveMode.CROUCH:
			_apply_selected_style(crouch_button)


func _apply_selected_style(btn: Button) -> void:
	btn.add_theme_color_override("font_color", selected_color)
	btn.modulate = selected_color


func _reset_button_style(btn: Button) -> void:
	btn.remove_theme_color_override("font_color")
	btn.modulate = Color(1, 1, 1, 1)


func _update_combat_button() -> void:
	pass

func update_ap_ui() -> void:
	if resources == null:
		return

	var ap: int = resources.action_points
	var max_ap: int = resources.max_action_points

	# Clear old points
	for child in ap_container.get_children():
		child.queue_free()

	# Create max AP points
	for i in range(max_ap):
		var point := POINT_BODY.instantiate()
		ap_container.add_child(point)
		var filled := false
		if GameManager.game_state == GameManager.GameState.COMBAT:
			filled = i < ap
		point.set_filled(filled)

func _update_weapon_buttons_ui() -> void:
	if resources == null or resources.stats_manager == null:
		weapon_one_ap.text = "AP ?"
		weapon_one_action.text = "—"
		weapon_two_ap.text = "AP ?"
		weapon_two_action.text = "—"
		return

	var sm: StatsManager = resources.stats_manager

	var ap_cost: int = sm.get_unarmed_action_cost()
	var action_key: String = sm.get_unarmed_action_key() # "punch" / "kick"

	weapon_one_ap.text = "AP %d" % ap_cost
	weapon_one_action.text = action_key.capitalize()

	weapon_two_ap.text = "AP %d" % ap_cost
	weapon_two_action.text = action_key.capitalize()


func _update_health_ui() -> void:
	# Placeholder: depends on how you store hp in resources (health/max_health exist in your PlayerResources)
	if resources == null:
		return

	if hp_bar:
		hp_bar.max_value = resources.max_health
		hp_bar.value = resources.health

	if health_display:
		health_display.text = "%d / %d" % [int(resources.health), int(resources.max_health)]


func _update_armor_ui() -> void:
	# Placeholder: fill when you compute armor
	if armor_label:
		armor_label.text = "Armor: --"
