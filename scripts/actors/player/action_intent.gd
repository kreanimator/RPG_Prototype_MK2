extends RefCounted
class_name ActionIntent

enum IntentType { MOVE, INTERACT, ATTACK, INVESTIGATE }

var intent_type: IntentType
var target_position: Vector3
var target_object: Node3D  # Interactable or Actor
var target_normal: Vector3 = Vector3.UP
var action_name: String = ""
var weapon_range: float = 0.0
var requires_facing: bool = true
var interaction_range: float = 1.5

static func create_move_intent(pos: Vector3, normal: Vector3) -> ActionIntent:
	var intent = ActionIntent.new()
	intent.intent_type = IntentType.MOVE
	intent.target_position = pos
	intent.target_normal = normal
	intent.requires_facing = false
	return intent

static func create_interact_intent(interactable: Interactable, _actor: Actor) -> ActionIntent:
	var intent = ActionIntent.new()
	intent.intent_type = IntentType.INTERACT
	intent.target_object = interactable
	intent.target_position = interactable.global_position
	intent.action_name = interactable.default_action
	intent.interaction_range = interactable.interaction_zone_size
	intent.requires_facing = true
	return intent

static func create_attack_intent(enemy: Actor, wp_range: float) -> ActionIntent:
	var intent = ActionIntent.new()
	intent.intent_type = IntentType.ATTACK
	intent.target_object = enemy
	intent.target_position = enemy.global_position
	intent.action_name = "attack"
	intent.weapon_range = wp_range
	intent.requires_facing = true
	return intent

static func create_investigate_intent(pos: Vector3) -> ActionIntent:
	var intent = ActionIntent.new()
	intent.intent_type = IntentType.INVESTIGATE
	intent.target_position = pos
	intent.action_name = "investigate"
	intent.requires_facing = false
	return intent
