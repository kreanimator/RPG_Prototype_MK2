extends CharacterBody3D
class_name Actor

# "Turn" here means this actor's ACTION SLOT in the round order.
# TurnController listens to this to advance to the next actor.
signal turn_finished(actor: Actor)

# Movement mode enum for actors (NPCs, enemies, etc.)
# Note: Player uses GameManager.MoveMode instead
enum ActorMoveMode {
	WALK,
	RUN,
	CROUCH
}

@export var actor_name: String = "Undefined"
@export var is_combatant: bool = true

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var faction_component: FactionComponent = get_node_or_null("FactionComponent")

var current_interactable: Interactable = null
var humanoid_model: HumanoidModel = null  # Reference to HumanoidModel for non-player actors

func _ready() -> void:
	add_to_group("actors")

func set_humanoid_model(model: HumanoidModel) -> void:
	"""Set the humanoid model reference (for non-player actors)"""
	humanoid_model = model

func set_target_position(pos: Vector3) -> void:
	if nav_agent == null:
		push_warning("%s has no NavigationAgent3D" % name)
		return
	# Snap to closest point on navmesh so agent always gets a valid target
	var map: RID = get_world_3d().navigation_map
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, pos)
	nav_agent.target_position = closest

func set_nav_agent(radius: float = 0.75,
 path_des_distance: float = 0.75,
 target_des_distance: float = 0.4 ) -> void:
	nav_agent.radius = radius
	nav_agent.path_desired_distance = path_des_distance
	nav_agent.target_desired_distance = target_des_distance
	nav_agent.avoidance_enabled = true
	nav_agent.avoidance_priority = 1.0


# -------------------------
# Combat / factions
# -------------------------
func is_hostile_to(other: Actor) -> bool:
	if other == null:
		return false
	if faction_component == null or other.faction_component == null:
		return false
	return faction_component.get_disposition_to(other.faction_component) == FactionComponent.Disposition.HOSTILE


func is_alive() -> bool:
	# Replace later with HP check if you have it
	return true


func can_take_turn() -> bool:
	# Called by TurnController when selecting next actor
	return is_combatant and is_alive()


# -------------------------
# Turn lifecycle hooks
# -------------------------
func on_turn_started(_turn_controller: Node) -> void:
	# Override in Player/Enemy
	pass


func on_turn_ended(_turn_controller: Node) -> void:
	# Override in Player/Enemy
	pass


# Call when this actor is done with its action slot (player pressed End Turn,
# AI finished thinking/acting, AP hit 0, etc.)
func finish_turn() -> void:
	turn_finished.emit(self)


# -------------------------
# Interaction helpers
# -------------------------
func get_interaction_info(requester: Actor = null) -> Dictionary:
	var info := {
		"name": actor_name,
		"type": "actor",
		"faction": null,
		"disposition": "neutral",
	}

	# Faction
	if faction_component:
		info["faction"] = faction_component.faction

	# Disposition relative to requester
	if requester != null and requester.faction_component and faction_component:
		var disp := requester.faction_component.get_disposition_to(faction_component)
		info["disposition"] = FactionComponent.Disposition.keys()[disp].to_lower()

	return info


func set_current_interactable(i: Interactable) -> void:
	current_interactable = i


func clear_current_interactable(i: Interactable) -> void:
	if current_interactable == i:
		current_interactable = null
