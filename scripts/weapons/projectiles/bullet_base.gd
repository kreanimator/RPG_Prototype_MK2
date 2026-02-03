extends RigidBody3D
class_name BulletBase

## Base class for all bullet projectiles

@export var speed: float = 40.0
@export var damage: int = 10
@export var lifetime: float = 10.0
@export var impact_force: float = 8.0
@export var impact_force_randomness: float = 0.3
@export var bullet_impact_scene: PackedScene
var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var previous_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 10
	body_entered.connect(_on_body_entered)
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_destroy_bullet)
	timer.start()

func initialize(start_position: Vector3, target_direction: Vector3, bullet_shooter: Node3D = null) -> void:
	global_position = start_position
	previous_position = start_position
	direction = target_direction.normalized()
	shooter = bullet_shooter
	linear_velocity = direction * speed


func _integrate_forces(_state: PhysicsDirectBodyState3D) -> void:
	# Update previous_position before physics integration
	previous_position = global_position


func _rotate_towards_direction(dir: Vector3) -> void:
	"""Rotate bullet to face the direction it's traveling"""
	if dir.length() > 0.001:
		# CapsuleMesh has its long axis along Y by default
		# So the bullet's forward direction is along the Y-axis
		# We need to make Y point along the direction vector
		var forward = dir.normalized()  # Direction the bullet should travel
		
		# Calculate right vector (X axis) - perpendicular to forward
		# Use a reference vector that's not parallel to forward
		var reference = Vector3.UP if abs(forward.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var right = reference.cross(forward).normalized()
		
		# If right is too small, try a different reference
		if right.length() < 0.1:
			reference = Vector3.FORWARD if abs(forward.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
			right = reference.cross(forward).normalized()
		
		# Calculate up vector (Z axis) - perpendicular to both forward and right
		var up = forward.cross(right).normalized()
		
		# Set the rotation using Basis
		# Basis constructor: Basis(x_axis, y_axis, z_axis)
		# For capsule: X = right, Y = forward (bullet direction), Z = up
		global_basis = Basis(right, forward, up).orthonormalized()

var hit_position: Vector3 = Vector3.ZERO
var colliding_body: Node = null

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	
	if _is_friendly_fire(body):
		return
	
	colliding_body = body
	# Get the actual collision contact point using raycast from previous position
	hit_position = _get_collision_point(body)
	if hit_position == Vector3.ZERO:
		# Fallback to bullet position if no collision point found
		hit_position = global_position
	
	_handle_body_collision(body)
	_create_impact_effect()
	_destroy_bullet()

func _get_collision_point(collision_body: Node) -> Vector3:
	# Simple approach: raycast from previous position to current position
	# This gives us the exact collision point, similar to Unity's col.contacts[0].point
	var space_state = get_world_3d().direct_space_state
	if not space_state or previous_position == Vector3.ZERO or previous_position == global_position:
		# Fallback: use midpoint between previous and current, or just current position
		if previous_position != Vector3.ZERO:
			return (previous_position + global_position) * 0.5
		return global_position
	
	# Cast ray from where bullet was to where it is now
	var query_ray = PhysicsRayQueryParameters3D.create(previous_position, global_position)
	query_ray.exclude = [get_rid()]
	
	# Exclude shooter and its collision children
	if shooter:
		if shooter is CollisionObject3D:
			query_ray.exclude.append((shooter as CollisionObject3D).get_rid())
		var shooter_children = shooter.find_children("*", "CollisionObject3D", true, true)
		for child in shooter_children:
			if child is CollisionObject3D:
				query_ray.exclude.append((child as CollisionObject3D).get_rid())
	
	var result = space_state.intersect_ray(query_ray)
	if result and result.has("position"):
		# Check if we hit the correct body (or any part of it)
		var hit_collider = result.get("collider")
		if hit_collider == collision_body:
			return result.position
		# Also check if hit collider is a child of collision_body
		if hit_collider is Node:
			var current = hit_collider as Node
			while current:
				if current == collision_body:
					return result.position
				current = current.get_parent()
	
	# If raycast didn't find it, use midpoint (simple fallback)
	return (previous_position + global_position) * 0.5

## Check if this would be friendly fire (same faction)
func _is_friendly_fire(body: Node) -> bool:
	if not shooter:
		return false
	
	if shooter.is_in_group("insects") and body.is_in_group("insects"):
		return true
	if shooter.is_in_group("mechs") and body.is_in_group("mechs"):
		return true
	
	return false

## Override this function in derived classes to handle specific body types
func _handle_body_collision(_body: Node) -> void:
	pass

## Handle player collision
func _handle_player_collision(player: Node) -> void:
	var player_model = player.get_node("PlayerModel") as PlayerModel
	if player_model and player_model.resources:
		player_model.resources.take_damage(damage)
		#print(get_script().get_global_name(), ": Hit player for ", damage, " damage!")

## Handle enemy collision
func _handle_enemy_collision(enemy: Node) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		#print(get_script().get_global_name(), ": Hit enemy for ", damage, " damage!")

## Handle rigid body collision (for physics objects)
func _handle_rigid_body_collision(rigid_body: RigidBody3D) -> void:
	_apply_impact_force(rigid_body)
	if rigid_body.has_method("take_damage"):
		rigid_body.take_damage(damage)
	#print(get_script().get_global_name(), ": Hit rigid body, applying force!")

func _apply_impact_force(rigid_body: RigidBody3D) -> void:
	var impact_direction = direction
	
	impact_direction.y += 0.2
	impact_direction = impact_direction.normalized()
	
	var random_factor = 1.0 + (randf() - 0.5) * impact_force_randomness
	var final_force = impact_force * random_factor
	
	var impact_point = global_position - rigid_body.global_position
	
	rigid_body.apply_impulse(impact_direction * final_force, impact_point)

func _create_impact_effect() -> void:
	pass

func _destroy_bullet() -> void:
	queue_free()
