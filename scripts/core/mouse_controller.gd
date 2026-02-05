extends Node
class_name InputCollector

@onready var player: Player = $".."

enum MouseMode { MOVE, ATTACK, INVESTIGATE }
var mouse_mode: MouseMode = MouseMode.MOVE

var _pending_right_click := false
var _pending_left_click := false
var _pending_mouse_pos := Vector2.ZERO

# NEW: latch movement intent
var _move_active := false
var _move_target := Vector3.ZERO
var _move_normal := Vector3.UP

func collect_input() -> InputPackage:
	var new_input = InputPackage.new()

	# Right click: switch mouse mode
	if _pending_right_click:
		_pending_right_click = false
		_cycle_mouse_mode()
		player.player_visuals.cursor_manager.set_cursor_mode(mouse_mode)

	# Left click: set intent / target
	if _pending_left_click:
		_pending_left_click = false

		var result = Utils.get_camera_raycast_from_mouse(_pending_mouse_pos, player.camera_node.cam, 1)
		if result:
			new_input.click_world_pos = result["position"]
			new_input.click_surface_rotation = result["normal"]
			new_input.has_click_world_pos = true

			match mouse_mode:
				MouseMode.MOVE:
					_move_active = true
					_move_target = new_input.click_world_pos
					_move_normal = new_input.click_surface_rotation

					# FIXME later move out of here (fine for now)
					player.set_target_position(_move_target)
					player.player_visuals.cursor_manager.show_target_point(_move_target, _move_normal)

				MouseMode.ATTACK:
					new_input.actions.append("attack")

				MouseMode.INVESTIGATE:
					new_input.actions.append("investigate")

	# Continuous move intent while travelling
	if _move_active:
		# if we arrived, stop latching
		if player.nav_agent.is_navigation_finished():
			_move_active = false
		else:
			var mode_name = GameManager.MoveMode.keys()[GameManager.move_mode].to_lower()
			new_input.actions.append(mode_name)

	# Default
	if new_input.actions.is_empty():
		new_input.actions.append("idle")

	return new_input

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
	mouse_mode = (int(mouse_mode) + 1) % MouseMode.keys().size() as MouseMode
	print("mouse_mode:", MouseMode.keys()[mouse_mode])
