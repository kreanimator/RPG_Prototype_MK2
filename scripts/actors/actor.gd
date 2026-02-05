extends CharacterBody3D
class_name Actor

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var faction_component: FactionComponent = get_node_or_null("FactionComponent")


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

func is_hostile_to(other: Actor) -> bool:
	if other == null:
		return false
	if faction_component == null or other.faction_component == null:
		return false

	return faction_component.get_disposition_to(other.faction_component) == FactionComponent.Disposition.HOSTILE
	
