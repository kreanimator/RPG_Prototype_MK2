extends Node3D
class_name Interactable

signal actor_entered(actor: Actor)
signal actor_exited(actor: Actor)
signal interaction_triggered(actor: Actor, action: String)

@export_range(0.5, 2, 0.1) var interaction_zone_size: float = 1.0
@export var default_action: String = "" # pick_up / pick_up_table / interact
@export var interaction_actions: Array[String] = []  # List of available actions

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_zone: CollisionShape3D = $InteractionArea/InteractionZone

var current_actor: Actor = null
var is_actor_in_range: bool = false

func _ready() -> void:
	interaction_zone.shape = interaction_zone.shape.duplicate()
	interaction_zone.shape.radius = interaction_zone_size
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Actor:
		current_actor = body
		is_actor_in_range = true
		body.set_current_interactable(self)
		actor_entered.emit(body)
		
		print("Actor entered interaction area: ", body.name)

func _on_body_exited(body: Node) -> void:
	if body is Actor:
		current_actor = body
		is_actor_in_range = false
		body.clear_current_interactable(self)
		actor_exited.emit(body)
		
		print("Player exited interaction area: ", body.name)

func can_interact() -> bool:
	return is_actor_in_range and current_actor != null

func get_current_actor() -> Actor:
	return current_actor

# Trigger interaction with specific action
func trigger_interaction(action: String = "") -> void:
	if not can_interact():
		return
	
	var actual_action = action if action != "" else default_action
	if actual_action == "":
		print("No action specified for interaction")
		return
	
	interaction_triggered.emit(current_actor, actual_action)
	print("Triggered interaction: ", actual_action, " for actor: ", current_actor.name)

# Check if specific action is available
func has_action(action: String) -> bool:
	return action in interaction_actions or action == default_action

# Get available actions
func get_available_actions() -> Array[String]:
	var actions = interaction_actions.duplicate()
	if default_action != "" and not actions.has(default_action):
		actions.append(default_action)
	return actions
