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

# Weapon buttons
@onready var weapon_one: Button = %WeaponOne
@onready var weapon_two: Button = %WeaponTwo

# Labels you already positioned in the scene
@onready var weapon_one_ap: Label = %WeaponOne/APCost
@onready var weapon_one_action: Label = %WeaponOne/UnarmedAction
@onready var weapon_two_ap: Label = %WeaponTwo/APCost
@onready var weapon_two_action: Label = %WeaponTwo/UnarmedAction

# Hotbar placeholders
@onready var hotbar_one: Button = %HotbarOne
@onready var hotbar_two: Button = %HotbarTwo
@onready var hotbar_three: Button = %HotbarThree

var player: Player
var is_player_turn: bool = true

const POINT_BODY := preload("uid://c83iqwhaadj3n")
var selected_color: Color = Color("#ffff87")

var turn_controller: TurnController = null
var resources: PlayerResources = null

# Optional: track which weapon button is “selected” visually (slot selection later)
enum WeaponSlot { ONE, TWO }
var _selected_weapon_slot: WeaponSlot = WeaponSlot.ONE


func _ready() -> void:
	_connect_buttons()

	_update_combat_button()
	_update_move_mode_buttons()
	_update_weapon_selected_style()

	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)


func set_player_resources(res: PlayerResources) -> void:
	_disconnect_resources()

	resources = res
	if resources == null:
		return
	player = resources.model.player as Player
	resources.action_points_changed.connect(_on_action_points_changed)
	turn_controller = get_tree().get_first_node_in_group("turn_controller")
	turn_controller.active_actor_changed.connect(_on_active_actor_changed)
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

	# Weapon buttons: use gui_input to detect left/right click
	weapon_one.gui_input.connect(_on_weapon_one_gui_input)
	weapon_two.gui_input.connect(_on_weapon_two_gui_input)

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


func _on_turn_button_pressed() -> void:
	if GameManager.game_state != GameManager.GameState.COMBAT:
		return

	# Always re-fetch (TurnController may be spawned later)
	if turn_controller == null or not is_instance_valid(turn_controller):
		turn_controller = get_tree().get_first_node_in_group("turn_controller")

	if turn_controller == null:
		print("[UI] End Turn pressed but no TurnController found in group")
		return

	# ✅ Only end turn if PLAYER is the active actor
	if player.is_player_turn:
		print("[UI] End Turn pressed -> end_current_actor_turn() current=", turn_controller.current_actor)
		turn_controller.end_current_actor_turn()
	else:
		print("[UI] End Turn ignored (not player turn). current=", turn_controller.current_actor)
		return




func _on_combat_button_pressed() -> void:
	GameManager.toggle_combat("ui_button")
	_update_combat_button()
	update_ap_ui()
	_update_weapon_buttons_ui()

	if GameManager.game_state == GameManager.GameState.COMBAT:
		print("[UI] Combat ON -> start_combat()")
		turn_controller.start_combat()
	else:
		print("[UI] Combat OFF -> end_combat()")
		turn_controller.end_combat()

func _on_skills_button_pressed() -> void:
	# TODO: open skills UI
	pass


# -------------------------
# Weapons: left = enter combat + attack mode, right = cycle action
# -------------------------

func _on_weapon_one_gui_input(event: InputEvent) -> void:
	_handle_weapon_gui_input(event, WeaponSlot.ONE)

func _on_weapon_two_gui_input(event: InputEvent) -> void:
	_handle_weapon_gui_input(event, WeaponSlot.TWO)

func _handle_weapon_gui_input(event: InputEvent, slot: WeaponSlot) -> void:
	if not (event is InputEventMouseButton):
		return

	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	# prevent the click from also triggering other UI logic
	accept_event()

	_selected_weapon_slot = slot
	_update_weapon_selected_style()

	if mb.button_index == MOUSE_BUTTON_LEFT:
		_on_weapon_left_click(slot)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_on_weapon_right_click(slot)


func _on_weapon_left_click(_slot: WeaponSlot) -> void:
	# Ensure combat is ON
	if GameManager.game_state != GameManager.GameState.COMBAT:
		GameManager.toggle_combat("weapon_left_click")
		_update_combat_button()
		update_ap_ui()

	# Switch to attack mode
	GameManager.mouse_mode = GameManager.MouseMode.ATTACK

	# (Optional) update your cursor immediately if you want:
	if resources and resources.model and resources.model.player and resources.model.player.player_visuals:
		resources.model.player.player_visuals.cursor_manager.set_cursor_mode(GameManager.mouse_mode)

	_update_weapon_buttons_ui()


func _on_weapon_right_click(_slot: WeaponSlot) -> void:
	# For now: cycle unarmed action punch/kick (duplicates both weapon buttons)
	if resources == null or resources.stats_manager == null:
		return

	var sm: StatsManager = resources.stats_manager
	if sm.current_unarmed_action == sm.CurrentUnarmedAction.PUNCH:
		sm.set_unarmed_action(sm.CurrentUnarmedAction.KICK)
	else:
		sm.set_unarmed_action(sm.CurrentUnarmedAction.PUNCH)

	_update_weapon_buttons_ui()


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


func _update_weapon_selected_style() -> void:
	# Visual “selected weapon button” placeholder (slot selection later)
	_reset_button_style(weapon_one)
	_reset_button_style(weapon_two)

	match _selected_weapon_slot:
		WeaponSlot.ONE:
			_apply_selected_style(weapon_one)
		WeaponSlot.TWO:
			_apply_selected_style(weapon_two)


func _update_combat_button() -> void:
	# Optional: if you want text updates back
	# if GameManager.game_state == GameManager.GameState.COMBAT:
	#     combat_button.text = "Exit Combat"
	# else:
	#     combat_button.text = "Enter Combat"
	pass


func update_ap_ui() -> void:
	if resources == null:
		return

	var ap: int = resources.action_points
	var max_ap: int = resources.max_action_points

	for child in ap_container.get_children():
		child.queue_free()

	# Only show enemy overlay in COMBAT and only when it's NOT the player's slot
	var show_enemy_turn := (GameManager.game_state == GameManager.GameState.COMBAT and not is_player_turn)

	for i in range(max_ap):
		var point: PointBody = POINT_BODY.instantiate()
		ap_container.add_child(point)

		# Enemy turn: all points show enemy indicator
		if show_enemy_turn:
			point.set_enemy_turn(true)
			continue

		# Player turn / non-combat: normal AP display
		point.set_enemy_turn(false)

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
	var action_key: String = sm.get_unarmed_action_key()

	weapon_one_ap.text = "AP %d" % ap_cost
	weapon_one_action.text = action_key.capitalize()
	weapon_two_ap.text = "AP %d" % ap_cost
	weapon_two_action.text = action_key.capitalize()


func _update_health_ui() -> void:
	if resources == null:
		return

	if hp_bar:
		hp_bar.max_value = resources.max_health
		hp_bar.value = resources.health

	if health_display:
		health_display.text = "%d / %d" % [int(resources.health), int(resources.max_health)]


func _update_armor_ui() -> void:
	if armor_label == null:
		return
	if resources == null:
		armor_label.text = "Armor: --"
		return

	armor_label.text = "Armor: %d" % resources.armor

func _on_active_actor_changed(actor: Actor) -> void:
	# Enemy turn if active actor is not the player
	is_player_turn = (actor == player)
	update_ap_ui()

# Hotbar placeholders
func _on_hotbar_one_pressed() -> void:
	pass
func _on_hotbar_two_pressed() -> void:
	pass
func _on_hotbar_three_pressed() -> void:
	pass
