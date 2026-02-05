extends LegsAction


@export var animation: String = "Jog_Fwd"
var move_speed: float = 7.0

func update(input: InputPackage, delta: float) -> void:
	player.velocity = velocity_by_nav(delta)
	var planar_v := player.velocity
	planar_v.y = 0.0
	if planar_v.length_squared() > 0.0001:
		player.look_at(player.global_position - planar_v.normalized(), Vector3.UP)

	player.move_and_slide()

	# stop -> switch to idle (input can also drive this; this is a safe fallback)
	#if player.nav_agent.is_navigation_finished():
		#switch_to("idle", input)

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

	var dir := to_next.normalized()
	new_velocity.x = dir.x * move_speed
	new_velocity.z = dir.z * move_speed
	return new_velocity

func setup_animator(previous_action: LegsAction, _input: InputPackage) -> void:
	if previous_action.anim_settings == anim_settings:
		legs_animator.play(animation, 0.15)
	else:
		legs_animator.play(animation, 0.0)
		legs_anim_settings.play(anim_settings, 0.15)
