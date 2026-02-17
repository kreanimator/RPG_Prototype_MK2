extends Sprite2D
class_name AnimatedCursor

enum PlaybackMode {
	LOOP,           # Continuously loop the animation
	PLAY_ON_HOVER,  # Play animation when hovering over interactive elements
	PLAY_ON_CLICK,  # Play animation when clicking
	PLAY_ONCE       # Play animation once when activated
}

@export_group("Animation")
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var default_animation: String = "idle"
@export var playback_mode: PlaybackMode = PlaybackMode.LOOP

@export_group("Hover Settings")
@export var hover_animation: String = "hover"
@export var hover_detection_enabled: bool = true
@export var interactable_collision_mask: int = 1 << 3  # MASK_INTERACTABLE (Layer 4)

@export_group("Click Settings")
@export var click_animation: String = "click"
@export var click_detection_enabled: bool = true

@export_group("Visual")
@export var cursor_hotspot: Vector2 = Vector2.ZERO

var _is_hovering: bool = false
var _has_clicked: bool = false
var _current_animation: String = ""

func _ready() -> void:
	# Set z-index to be on top (for CanvasLayer)
	z_index = z_index
	
	# Find AnimationPlayer if not set
	if animation_player == null:
		animation_player = _find_animation_player()
	
	if animation_player == null:
		push_error("[AnimatedCursor] No AnimationPlayer found! Please add one as a child or set it via export.")
		return
	
	# Connect to animation finished signal
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# Start with default animation based on mode
	_play_default_animation()

func _process(_delta: float) -> void:
	# Update position to follow mouse
	var mouse_pos := get_viewport().get_mouse_position()
	global_position = mouse_pos - cursor_hotspot
	
	# Handle hover detection
	if hover_detection_enabled and playback_mode == PlaybackMode.PLAY_ON_HOVER:
		_check_hover_state()

func _find_animation_player() -> AnimationPlayer:
	# Look for AnimationPlayer in children
	for child in get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
	
	# Look in parent
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is AnimationPlayer:
				return child as AnimationPlayer
	
	return null

func _play_default_animation() -> void:
	if animation_player == null or default_animation.is_empty():
		return
	
	if not animation_player.has_animation(default_animation):
		push_warning("[AnimatedCursor] Animation '%s' not found in AnimationPlayer!" % default_animation)
		return
	
	match playback_mode:
		PlaybackMode.LOOP:
			# Play animation (should be set to loop in AnimationPlayer editor)
			animation_player.play(default_animation)
		
		PlaybackMode.PLAY_ONCE:
			# Play animation once (should be set to no loop in AnimationPlayer editor)
			animation_player.play(default_animation)
		
		PlaybackMode.PLAY_ON_HOVER:
			# Don't play until hover
			animation_player.stop()
		
		PlaybackMode.PLAY_ON_CLICK:
			# Don't play until click
			animation_player.stop()

func _check_hover_state() -> void:
	if animation_player == null:
		return
	
	var viewport := get_viewport()
	if viewport == null:
		return
	
	# Check if mouse is over any interactive element (3D interactables or UI controls)
	var mouse_pos := viewport.get_mouse_position()
	var is_hovering_now := _is_mouse_over_interactive_element(mouse_pos)
	
	if is_hovering_now != _is_hovering:
		_is_hovering = is_hovering_now
		_handle_hover_change()

func _is_mouse_over_interactive_element(mouse_pos: Vector2) -> bool:
	# Check if mouse is over any Control node that can receive input
	var viewport := get_viewport()
	if viewport == null:
		return false
	
	# Check if there are any interactive controls in the "interactive" group
	var controls := get_tree().get_nodes_in_group("interactive")
	for ctrl in controls:
		if ctrl is Control:
			var rect := (ctrl as Control).get_global_rect()
			if rect.has_point(mouse_pos):
				return true
	
	# Check for 3D interactables (Area3D components)
	var space_state_3d := get_viewport().get_world_3d().direct_space_state
	if space_state_3d != null:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var from := camera.project_ray_origin(mouse_pos)
			var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
			var query_3d := PhysicsRayQueryParameters3D.create(from, to)
			query_3d.collision_mask = interactable_collision_mask
			var result_3d := space_state_3d.intersect_ray(query_3d)
			if result_3d:
				# Check if the collider is an Interactable or has an Interactable component
				var collider = result_3d.get("collider")
				if collider != null:
					# Check if it's an Interactable directly
					if collider is Interactable:
						return true
					# Check if it's a child/parent of an Interactable
					var node: Node = collider
					while node != null:
						if node is Interactable:
							return true
						node = node.get_parent()
				return true
	
	return false

func _handle_hover_change() -> void:
	if animation_player == null:
		return
	
	if _is_hovering:
		# Start hover animation (should be set to loop in AnimationPlayer editor)
		if animation_player.has_animation(hover_animation):
			animation_player.play(hover_animation)
		elif animation_player.has_animation(default_animation):
			animation_player.play(default_animation)
	else:
		# Stop animation or return to default
		animation_player.stop()

func play_click_animation() -> void:
	if not click_detection_enabled or playback_mode != PlaybackMode.PLAY_ON_CLICK:
		return
	
	if animation_player == null:
		return
	
	if animation_player.has_animation(click_animation):
		# Play click animation (should be set to no loop in AnimationPlayer editor)
		animation_player.play(click_animation)
		_current_animation = click_animation
	elif animation_player.has_animation(default_animation):
		animation_player.play(default_animation)
		_current_animation = default_animation

func play_animation(animation_name: String, loop: bool = false) -> void:
	if animation_player == null:
		return
	
	if not animation_player.has_animation(animation_name):
		push_warning("[AnimatedCursor] Animation '%s' not found!" % animation_name)
		return
	
	# Note: Loop mode should be configured in AnimationPlayer editor for each animation
	# The 'loop' parameter is informational - configure animations in the editor accordingly
	animation_player.play(animation_name)
	_current_animation = animation_name

func stop_animation() -> void:
	if animation_player != null:
		animation_player.stop()

func _on_animation_finished(animation_name: String) -> void:
	match playback_mode:
		PlaybackMode.PLAY_ONCE:
			# Animation finished, stop
			animation_player.stop()
		
		PlaybackMode.PLAY_ON_CLICK:
			# Return to default state after click animation
			if animation_name == click_animation or animation_name == default_animation:
				animation_player.stop()
		
		PlaybackMode.PLAY_ON_HOVER:
			# If hover ended, stop animation
			if not _is_hovering:
				animation_player.stop()
		
		PlaybackMode.LOOP:
			# Should not happen if loop is set correctly, but handle it anyway
			if animation_name == default_animation:
				animation_player.play(default_animation)

# Public API for external control
func set_playback_mode(mode: PlaybackMode) -> void:
	playback_mode = mode
	_play_default_animation()

func set_default_animation(animation_name: String) -> void:
	default_animation = animation_name
	_play_default_animation()

func is_playing() -> bool:
	if animation_player == null:
		return false
	return animation_player.is_playing()

func get_current_animation() -> String:
	if animation_player == null:
		return ""
	return animation_player.current_animation
