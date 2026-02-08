extends Node
class_name InputCollector

@onready var player: Player = $".."

# Collision masks (bitfields)
# Interactable is on Layer 4 => mask bit = 1 << (4-1) = 8
const MASK_INTERACTABLE := 1 << 3

# Your "ground/world" mask - keep what you actually use.
# In your current code you pass `1`, which means Layer 1 only.
const MASK_GROUND := 1 << 0

var _pending_right_click := false
var _pending_left_click := false
var _pending_mouse_pos := Vector2.ZERO

# latch movement intent
var _move_active := false
var _move_target := Vector3.ZERO
var _move_normal := Vector3.UP

func collect_input() -> InputPackage:
	var new_input := InputPackage.new()

	# Right click: switch mouse mode
	if _pending_right_click:
		_pending_right_click = false
		_cycle_mouse_mode()
		player.player_visuals.cursor_manager.set_cursor_mode(GameManager.mouse_mode)

	# Left click: act in current mode
	if _pending_left_click and GameManager.can_perform_action:
		_pending_left_click = false

		match GameManager.mouse_mode:
			GameManager.MouseMode.INTERACT:
				_handle_interact_click(new_input)

			_:
				_handle_world_click(new_input)

	# Clear pending click if action was blocked
	elif _pending_left_click:
		_pending_left_click = false

	# Continuous move intent while travelling
	if _move_active:
		if player.nav_agent.is_navigation_finished():
			_move_active = false
		else:
			var mode_name = GameManager.MoveMode.keys()[GameManager.move_mode].to_lower()
			new_input.actions.append(mode_name)

	# Default
	if new_input.actions.is_empty():
		if GameManager.move_mode == GameManager.MoveMode.CROUCH:
			new_input.actions.append("crouch_idle")
		new_input.actions.append("idle")

	return new_input


func _handle_interact_click(new_input: InputPackage) -> void:
	# Raycast for Area3D interactables (collide_with_areas must be true)
	var hit = Utils.get_camera_raycast_from_mouse(
		_pending_mouse_pos,
		player.camera_node.cam,
		false,  # collide_with_bodies
		true,   # collide_with_areas
		MASK_INTERACTABLE
	)

	if hit and hit.has("collider") and hit["collider"] is Interactable:
		var inter := hit["collider"] as Interactable
		player.current_interactable = inter
		if inter.can_interact():
			new_input.actions.append("interact")
		return

	## Fallback: if you're already in range of something, allow interact without ray hit
	#if player.current_interactable and player.current_interactable.can_interact():
		#new_input.actions.append("interact")


func _handle_world_click(new_input: InputPackage) -> void:
	# Raycast world/ground using bodies
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
			_move_active = true
			_move_target = new_input.click_world_pos
			_move_normal = new_input.click_surface_rotation

			player.set_target_position(_move_target)
			player.player_visuals.cursor_manager.show_target_point(_move_target, _move_normal)

		GameManager.MouseMode.ATTACK:
			new_input.actions.append("attack")

		GameManager.MouseMode.INVESTIGATE:
			new_input.actions.append("investigate")


func _input(event: InputEvent) -> void:
	if Utils.is_mouse_over_gui():
		return

	# Right click: cycle mode
	if event is InputEventMouseButton and event.is_action_pressed("right_click"):
		_pending_right_click = true

	# Left click: act in current mode
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		_pending_left_click = true
		_pending_mouse_pos = event.position


func _cycle_mouse_mode() -> void:
	GameManager.mouse_mode = (int(GameManager.mouse_mode) + 1) % GameManager.MouseMode.keys().size() as GameManager.MouseMode
	print("mouse_mode:", GameManager.MouseMode.keys()[GameManager.mouse_mode])
