extends BulletBase

const BULLET_COLLISSION = preload("uid://tjjq2xwr6r7f")

	
## Override to handle player weapon collision logic
func _handle_body_collision(body: Node) -> void:
	# Check if it's the player
	if body.is_in_group("player"):
		_handle_player_collision(body)
	
	# Check if it's an enemy (spider, turret, other enemies)
	elif body.is_in_group("insects") or body.is_in_group("mechs"):
		_handle_enemy_collision(body)
	
	# Check if it's a rigid body (like cardboard boxes, barrels)
	elif body is RigidBody3D:
		_handle_rigid_body_collision(body)

func _create_impact_effect() -> void:
	var impact_particles = BULLET_COLLISSION.instantiate() as GPUParticles3D
	get_tree().current_scene.add_child(impact_particles)
	# Use the actual hit position from collision detection
	impact_particles.global_position = hit_position
	var hit_dir := direction.normalized()
	if hit_dir.length() > 0.001:
		impact_particles.look_at(impact_particles.global_position + hit_dir, Vector3.UP)
	impact_particles.emitting = true
	get_tree().create_timer(impact_particles.lifetime).timeout.connect(func():
		if is_instance_valid(impact_particles):
			impact_particles.queue_free()
	)
