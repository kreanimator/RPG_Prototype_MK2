extends LegsAction


@export var animation: String = "Walk"
var move_speed: float = 3

func update(_input: InputPackage, delta: float) -> void:
	player.velocity = velocity_by_nav(delta)
	player.move_and_slide()


func velocity_by_nav(delta: float) -> Vector3:
	var new_velocity := player.velocity

	if not player.is_on_floor():
		new_velocity.y += gravity * delta
	else:
		new_velocity.y = 0.0

	var agent: NavigationAgent3D = player.nav_agent
	if agent == null or agent.is_navigation_finished():
		new_velocity.x = move_toward(new_velocity.x, 0.0, move_speed)
		new_velocity.z = move_toward(new_velocity.z, 0.0, move_speed)
		return new_velocity

	var next := agent.get_next_path_position()
	var to_next := next - player.global_position
	to_next.y = 0.0

	if to_next.length_squared() < 0.0001:
		new_velocity.x = 0.0
		new_velocity.z = 0.0
		return new_velocity

	# --- ROTATION (ported from Player script) ---
	var target_yaw: float = atan2(to_next.x, to_next.z)
	var t: float = 1.0 - exp(-player.turn_speed * delta)
	player.rotation.y = lerp_angle(player.rotation.y, target_yaw, t)
	# --- end rotation ---

	var dir := to_next.normalized()
	new_velocity.x = dir.x * move_speed
	new_velocity.z = dir.z * move_speed
	return new_velocity


func setup_animator(previous_action: LegsAction, _input: InputPackage) -> void:
	if previous_action.anim_settings == anim_settings: # ie both are simple of AnimatorModifier type
		legs_animator.play(animation, 0.15)
	else:
		legs_animator.play(animation, 0)
		legs_anim_settings.play(anim_settings, 0.15)
