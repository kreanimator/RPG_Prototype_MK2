extends Control
class_name MouseDebugOverlay

var mouse_interactor: MouseInteractor
@onready var player_visuals: PlayerVisuals = $"../.."

var label: Label

func _ready() -> void:
	# create label at runtime
	label = Label.new()
	label.text = "raycast: none"
	label.modulate = Color(1, 1, 0) # yellow text
	add_child(label)

func _process(_delta: float) -> void:
	# follow mouse
	label.position = get_viewport().get_mouse_position() + Vector2(16, 16)

func set_mousw_interactor(interactor: MouseInteractor):
	mouse_interactor = interactor
	mouse_interactor.hover_changed.connect(_on_hover_changed)
	
func _on_hover_changed(hit: Dictionary) -> void:
	if hit.is_empty():
		label.text = "no hit"
		return

	var collider = hit.get("collider", null)

	var text := ""
	if collider:
		text += "collider: %s\n" % collider.name

		# If it's an Actor, print hover info (enemy info etc.)
		if collider is Actor:
			var player := get_tree().get_first_node_in_group("player") as Actor
			var info = (collider as Actor).get_interaction_info(player)

			for k in info.keys():
				text += "%s: %s\n" % [str(k), str(info[k])]

		# Or: if any node implements get_hover_info()
		elif collider.has_method("get_hover_info"):
			var info2: Dictionary = collider.call("get_hover_info")
			for k in info2.keys():
				text += "%s: %s\n" % [str(k), str(info2[k])]

	if hit.has("position"):
		text += "pos: %s\n" % str(hit["position"])
	if hit.has("normal"):
		text += "normal: %s\n" % str(hit["normal"])

	label.text = text
