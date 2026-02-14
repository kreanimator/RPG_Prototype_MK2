extends Node3D
class_name DummyInteractable

@export var destroy_on_interact: bool = true
@export var action: String
@export var dependant: Node3D
@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable == null:
		push_error("%s: Missing child node 'Interactable'." % name)
		return

	# Setup actions for testing
	interactable.default_action = action
	interactable.interaction_actions = [action]

	# Connect event
	if not interactable.interaction_triggered.is_connected(_on_interaction_triggered):
		interactable.interaction_triggered.connect(_on_interaction_triggered)

func _on_interaction_triggered(actor: Actor, act: String) -> void:
	print("[DummyInteractable] action=", act, " by=", actor.name)

	if destroy_on_interact:
		print("[DummyInteractable] queue_free()")
		queue_free()
	if dependant:
		dependant.toggle_movement()
