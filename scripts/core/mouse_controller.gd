extends Node
class_name InputCollector

@onready var player: Player = $".."

enum MouseMode { MOVE, ATTACK, INVESTIGATE }
var mouse_mode: MouseMode = MouseMode.MOVE

var _pending_right_click := false
var _pending_left_click := false
var _pending_mouse_pos := Vector2.ZERO


func _process(_delta: float) -> void:
	collect_input()


func collect_input() -> InputPackage:
	var new_input = InputPackage.new()

	# Right click: switch mouse mode
	if _pending_right_click:
		_pending_right_click = false
		_cycle_mouse_mode()
		player.player_visuals.cursor_manager.set_cursor_mode(mouse_mode)

	# Left click: execute current mode action
	if _pending_left_click:
		_pending_left_click = false

		var result = Utils.get_camera_raycast_from_mouse(_pending_mouse_pos, player.camera_node.cam, 1)
		if result:
			new_input.click_world_pos = result["position"]
			new_input.click_surface_rotation = result["normal"]
			new_input.has_click_world_pos = true

			match mouse_mode:
				MouseMode.MOVE:
					new_input.actions.append("move")

					#### FIXME Should be moved out of here
					player.set_target_position(new_input.click_world_pos)
					player.player_visuals.cursor_manager.set_target_point(new_input.click_world_pos, new_input.click_surface_rotation)
					######################################################

				MouseMode.ATTACK:
					# you can later route this into combat system
					new_input.actions.append("attack")

				MouseMode.INVESTIGATE:
					# you can later route this into interaction/inspection system
					new_input.actions.append("investigate")

	# if new_input.actions.is_empty():
	new_input.actions.append("idle")

	return new_input


func _input(event: InputEvent) -> void:
	if Utils.is_mouse_over_gui():
		return

	# Right click: switch mouse mode (no position needed)
	if event is InputEventMouseButton and event.is_action_pressed("right_click"):
		_pending_right_click = true

	# Left click: perform action in current mode (position needed)
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		_pending_left_click = true
		_pending_mouse_pos = event.position

func _cycle_mouse_mode() -> void:
	mouse_mode = (int(mouse_mode) + 1) % MouseMode.keys().size() as MouseMode
	print("mouse_mode:", MouseMode.keys()[mouse_mode])
