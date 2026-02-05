extends Node3D

var data = {}

func generate_uuid() -> String:
	var rng = RandomNumberGenerator.new()
	var template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	var uuid = ""
	for c in template:
		match c:
			"x":
				uuid += "%x" % rng.randi_range(0, 15)
			"y":
				uuid += "%x" % ((rng.randi_range(0, 15) & 0x3) | 0x8)
			"-":
				uuid += "-"
			_:
				uuid += c
	return uuid

func is_mouse_over_gui() -> bool:
	"""Checks if the mouse is over any GUI element or if UI is blocking input."""
	var tree = get_tree()
	if not tree or not tree.root:
		return false
	
	# Check mouse position
	var viewport = tree.root.get_viewport()
	if not viewport:
		return false
	
	return _find_interactive_control_at_position(tree.root, viewport.get_mouse_position()) != null

func _find_interactive_control_at_position(node: Node, pos: Vector2) -> Control:
	"""Recursively finds an interactive Control at the given position."""
	if not node is Control:
		# Check children of non-Control nodes
		for child in node.get_children():
			var result = _find_interactive_control_at_position(child, pos)
			if result != null:
				return result
		return null
	
	var control = node as Control
	# If control is not visible, skip it and all its children (invisible controls shouldn't block input)
	if not control.visible:
		return null
	
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		# Still check children if mouse filter is ignore
		for child in control.get_children():
			var result = _find_interactive_control_at_position(child, pos)
			if result != null:
				return result
		return null
	
	if not control.get_global_rect().has_point(pos):
		return null
	
	# Check children first (they're on top)
	for child in control.get_children():
		var child_control = _find_interactive_control_at_position(child, pos)
		if child_control != null:
			return child_control
	
	# Check if this control is interactive
	if _is_interactive_control(control, pos):
		return control
	return null

func _is_interactive_control(control: Control, pos: Vector2) -> bool:
	"""Checks if a control is interactive (button, input field, or has interactive child at position)."""
	# Skip invisible controls
	if not control.visible:
		return false
	
	# Direct interactive control types
	if _is_interactive_type(control):
		return true
	
	# Check if mouse is over an interactive child
	for child in control.get_children():
		if not child is Control:
			continue
		var child_control = child as Control
		if child_control.visible and child_control.get_global_rect().has_point(pos):
			if _is_interactive_type(child_control) or _is_interactive_control(child_control, pos):
				return true
	
	return false

func _is_interactive_type(control: Control) -> bool:
	"""Checks if a control is a directly interactive type (button, input, etc.)."""
	return control is BaseButton or control is LineEdit or control is TextEdit or \
		   control is OptionButton or control is CheckBox or control is CheckButton or \
		   control is ColorPicker or control is SpinBox or control is Slider

func get_camera_raycast_from_mouse(mouse_pos: Vector2, camera: Camera3D, collission_mask: int= 42):
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from; query.to = to; query.collision_mask = collission_mask
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)
	if result.size() > 0: return result 

func remove_children(obj) -> void:
		for i in obj.get_children():
			i.queue_free()

func print_node_hierarchy(node, indent="") -> void:
	print(indent + node.name)
	for child in node.get_children():
		print_node_hierarchy(child, indent + "  ")

func print_bones(skeleton: Skeleton3D):
	var count := skeleton.get_bone_count()
	print("Total bones:", count)

	for i in range(count):
		var bone_name = skeleton.get_bone_name(i)
		var parent = skeleton.get_bone_parent(i)
		print("Bone", i, ":", bone_name, " | parent index:", parent)
		
func print_bone_indexes_with_names(skeleton: Skeleton3D) -> void:
	for i in range(skeleton.get_bone_count()):
		print(i, " : ", skeleton.get_bone_name(i))

func print_animation_info(anim_name: String, animations_source) -> void:
	if animations_source == null:
		push_error("animations_source is null")
		return

	if not animations_source.has_animation(anim_name):
		push_error("AnimationPlayer has no animation named: " + anim_name)
		print("Available animations: ", animations_source.get_animation_list())
		return

	var anim: Animation = animations_source.get_animation(anim_name)
	if anim == null:
		push_error("get_animation returned null for: " + anim_name)
		return

	print("\n=== Animation Info:", anim_name, "===")
	print("length:", anim.length)
	print("loop_mode:", anim.loop_mode) # 0/1/2 enum
	print("step:", anim.step)
	print("tracks:", anim.get_track_count())

	for ti in range(anim.get_track_count()):
		var ttype := anim.track_get_type(ti)
		var path := anim.track_get_path(ti)

		# Not all track types expose key count the same way, but for most this works:
		var keys := anim.track_get_key_count(ti)

		print("- track#", ti,
			" type:", ttype,
			" path:", path,
			" keys:", keys
		)

	print("=== end ===\n")

func print_all_animations_tracks(animations_source) -> void:
	if animations_source == null:
		push_error("animations_source is null")
		return
	
	var list: PackedStringArray = animations_source.get_animation_list()
	print("\n=== Animations track counts (", list.size(), ") ===")
	
	for anim_name in list:
		var anim: Animation = animations_source.get_animation(anim_name)
		if anim == null:
			print(anim_name, " -> NULL")
			continue
		print(anim_name, " -> tracks:", anim.get_track_count(), " length:", anim.length, " loop_mode:", anim.loop_mode)
	
	print("=== end ===\n")
