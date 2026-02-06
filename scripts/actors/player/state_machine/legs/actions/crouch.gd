extends LegsAction

@export var animation: String = "Crouch_Fwd"
@export var move_speed: float = 3.0
@export var turn_speed: float = 6.0

@export var min_move_to_charge: float = 0.01

var _prev_pos: Vector3
var _prev_valid: bool = false

func update(_input: InputPackage, delta: float) -> void:
	# Track position before movement
	if not _prev_valid:
		_prev_pos = player.global_position
		_prev_valid = true

	# Move
	player.velocity = velocity_by_nav(delta)
	player.move_and_slide()

	# Charge AP by distance
	_charge_ap_by_distance()

	# Stop if out of AP in combat
	if GameManager.is_in_combat() and _is_out_of_ap():
		_stop_nav_motion()

func _charge_ap_by_distance() -> void:
	var now := player.global_position
	var dv := now - _prev_pos
	dv.y = 0.0
	var dist := dv.length()
	_prev_pos = now

	if dist < min_move_to_charge:
		return

	player.player_model.resources.spend_ap_for_movement(dist)

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

	var target_yaw: float = atan2(to_next.x, to_next.z)
	var t: float = 1.0 - exp(-turn_speed * delta)
	player.rotation.y = lerp_angle(player.rotation.y, target_yaw, t)

	var dir := to_next.normalized()
	new_velocity.x = dir.x * move_speed
	new_velocity.z = dir.z * move_speed
	return new_velocity

func setup_animator(previous_action: LegsAction, _input: InputPackage) -> void:
	if previous_action.anim_settings == anim_settings:
		legs_animator.play(animation, 0.15)
	else:
		legs_animator.play(animation, 0)
		legs_anim_settings.play(anim_settings, 0.15)

func on_exit_action() -> void:
	_prev_valid = false

func _is_out_of_ap() -> bool:
	return player.player_model.resources.action_points <= 0

func _stop_nav_motion() -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.set_target_position(player.global_position)
