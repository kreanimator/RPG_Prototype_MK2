extends Node3D
class_name DamageIndicator

enum IndicatorType { DAMAGE, HEAL, MISS }

@export var font_size := 75
@export var label_range := 4
@export var animation_duration := 1.5

var _scene_ref: Node = null

## Create a damage indicator at the specified position
## type: DAMAGE (red), HEAL (green), MISS (yellow)
## value: damage/heal amount (ignored for MISS)
static func create_at_position(position: Vector3, type: IndicatorType, value: float = 0.0) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	
	# Create temporary indicator node immediately
	var indicator := DamageIndicator.new()
	scene.add_child(indicator)
	# Position slightly above the actor (head level)
	indicator.global_position = position + Vector3(0, 1.5, 0)
	
	# Store scene reference for label creation
	indicator._scene_ref = scene
	
	# Create indicator immediately - TurnController delay ensures it has time to appear
	match type:
		IndicatorType.DAMAGE:
			indicator._create_damage_indicator(int(value))
		IndicatorType.HEAL:
			indicator._create_heal_indicator(int(value))
		IndicatorType.MISS:
			indicator._create_miss_indicator()

func _create_damage_indicator(value: int) -> void:
	var label := _create_label(str(value), Color.CRIMSON)
	_tween_indicator(label)

func _create_heal_indicator(value: int) -> void:
	var label := _create_label("+" + str(value), Color.GREEN)
	_tween_indicator(label)

func _create_miss_indicator() -> void:
	var label := _create_label("MISS", Color.YELLOW)
	_tween_indicator(label)

func _create_label(text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = font_size / 2
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	
	# Use stored scene reference or fallback to get_tree()
	var scene: Node = _scene_ref if _scene_ref != null else get_tree().current_scene
	
	if scene != null and is_instance_valid(scene):
		scene.add_child(label)
		label.global_position = global_position
	else:
		# Fallback: add to indicator's parent if scene is invalid
		var parent := get_parent()
		if parent != null:
			parent.add_child(label)
			label.global_position = global_position
	
	return label

func _tween_indicator(label: Label3D) -> void:
	# Create tween on the label itself to ensure it persists
	var tween := label.create_tween()
	var random_target_position := Vector3(
		randf_range(-label_range, label_range),
		randf_range(0, label_range * 2),  # Move upward more
		randf_range(-label_range, label_range),
	)
	tween.tween_property(label, "position", label.global_position + random_target_position, animation_duration)
	tween.parallel()
	tween.tween_property(label, "modulate:a", 0, animation_duration)
	tween.parallel()
	tween.tween_property(label, "outline_modulate:a", 0, animation_duration)
	# Clean up both label and indicator node when done
	tween.tween_callback(func(): 
		label.queue_free()
		queue_free()
	)
