extends Node
class_name InputCollector

@onready var player: Player = $".."

# Physics layers (bitfields)
const MASK_INTERACTABLE := 1 << 3   # Layer 4
const MASK_GROUND       := 1 << 0   # Layer 1
const MASK_ACTOR        := 1 << 1   # Layer 2

var _pending_right_click := false
var _pending_left_click := false
var _pending_mouse_pos := Vector2.ZERO

func collect_input() -> InputPackage:
	var new_input := InputPackage.new()

	# Right click: cycle mouse mode
	if _pending_right_click:
		_pending_right_click = false
		_cycle_mouse_mode()
		player.player_visuals.cursor_manager.set_cursor_mode(GameManager.mouse_mode)

	# Left click: act in current mode
	if _pending_left_click:
		_pending_left_click = false

		if GameManager.can_perform_action:
			match GameManager.mouse_mode:
				GameManager.MouseMode.INTERACT:
					_handle_interact_click()
				GameManager.MouseMode.ATTACK:
					_handle_attack_click()
				_:
					_handle_world_click(new_input)

	# If action resolver is running an intent, it drives the action string
	var action_resolver := player.player_model.action_resolver as ActionResolver
	if action_resolver and action_resolver.is_executing():
		var action := action_resolver.get_current_action_for_input()
		if action != "":
			new_input.actions.append(action)
			return new_input

	# Default idle
	if new_input.actions.is_empty():
		if GameManager.move_mode == GameManager.MoveMode.CROUCH:
			new_input.actions.append("crouch_idle")
		new_input.actions.append("idle")

	return new_input


func _handle_interact_click() -> void:
	var hit = Utils.get_camera_raycast_from_mouse(
		_pending_mouse_pos,
		player.camera_node.cam,
		false,  # collide_with_bodies
		true,   # collide_with_areas
		MASK_INTERACTABLE
	)

	if not hit or not hit.has("collider"):
		return

	var col = hit["collider"]
	if col is Interactable:
		var inter := col as Interactable
		var intent := ActionIntent.create_interact_intent(inter, player)

		var resolver := player.player_model.action_resolver as ActionResolver
		if resolver:
			resolver.set_intent(intent)


func _handle_world_click(new_input: InputPackage) -> void:
	var result = Utils.get_camera_raycast_from_mouse(
		_pending_mouse_pos,
		player.camera_node.cam,
		true,   # collide_with_bodies
		false,  # collide_with_areas
		MASK_GROUND
	)

	if not result:
		return

	new_input.click_world_pos = result["position"]
	new_input.click_surface_rotation = result["normal"]
	new_input.has_click_world_pos = true

	match GameManager.mouse_mode:
		GameManager.MouseMode.MOVE:
			var intent := ActionIntent.create_move_intent(result["position"], result["normal"])
			var resolver := player.player_model.action_resolver as ActionResolver
			if resolver:
				resolver.set_intent(intent)

			player.player_visuals.cursor_manager.show_target_point(result["position"], result["normal"])

		GameManager.MouseMode.INVESTIGATE:
			# For now just to move to every object, will changed and refactored later it is not core functionality now
			var intent := ActionIntent.create_investigate_intent(result["position"])
			var resolver := player.player_model.action_resolver as ActionResolver
			if resolver:
				resolver.set_intent(intent)


func _handle_attack_click() -> void:
	# Allow both bodies and areas (hurtboxes etc.)
	var hit = Utils.get_camera_raycast_from_mouse(
		_pending_mouse_pos,
		player.camera_node.cam,
		true,   # collide_with_bodies
		true,   # collide_with_areas
		MASK_ACTOR
	)

	if not hit or not hit.has("collider"):
		return

	var collider: Node = hit["collider"]
	var enemy_actor := _find_actor_from_node(collider)
	if enemy_actor == null:
		return

	var rng := _get_current_attack_range()
	var intent := ActionIntent.create_attack_intent(enemy_actor, rng)

	var resolver := player.player_model.action_resolver as ActionResolver
	if resolver:
		resolver.set_intent(intent)


func _find_actor_from_node(n: Node) -> Actor:
	# Raycasts often hit a child (CollisionShape3D / Area3D / etc.), so walk parents.
	var cur: Node = n
	while cur:
		if cur is Actor:
			return cur as Actor
		cur = cur.get_parent()
	return null


func _unhandled_input(event: InputEvent) -> void:
	if Utils.is_mouse_over_gui():
		return

	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_pending_right_click = true

		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_pending_left_click = true
			_pending_mouse_pos = mb.position


func _get_current_attack_range() -> float:
	# TODO: later return equipped weapon range if exists
	return 1.6


func _cycle_mouse_mode() -> void:
	GameManager.mouse_mode = (int(GameManager.mouse_mode) + 1) % GameManager.MouseMode.keys().size() as GameManager.MouseMode
