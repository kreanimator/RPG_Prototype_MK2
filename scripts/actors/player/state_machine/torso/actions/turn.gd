extends TorsoAction

var overrotation : float 
var rotation_period : float = 1.05
var turn_target_position: Vector3

func setup_animator(_input : InputPackage):
	# Get target position from parent behaviour (interact or attack)
	if parent_behaviour:
		turn_target_position = parent_behaviour.get_turn_target_position()
	else:
		# Fallback: forward direction
		var forward_dir := -player.global_transform.basis.z
		turn_target_position = player.global_position + forward_dir

	var to_target := player.global_position.direction_to(turn_target_position)

	var angle = player.global_basis.z.signed_angle_to(to_target, Vector3.UP)
	if angle > 0:
		animation = "Turn90_L"
		overrotation = angle - PI / 2
	else:
		animation = "Turn90_R"
		overrotation = angle + PI / 2
	
	if torso_anim_settings.current_animation == "simple": # ie both are simple of AnimatorModifier type
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)
	
	if parent_behaviour.legs.legs_anim_settings.current_animation == "simple": # ie both are simple of AnimatorModifier type
		parent_behaviour.legs.simple_animator.play(animation, 0.15)
	else:
		parent_behaviour.legs.simple_animator.play(animation, 0)
		parent_behaviour.legs.legs_anim_settings.play("simple", 0.15)

func update(_input : InputPackage, delta : float):
	# Check if we're already facing the target correctly (early stop)
	var to_target := player.global_position.direction_to(turn_target_position)
	var current_angle := player.global_basis.z.angle_to(to_target)
	
	if current_angle <= 0.3:  # ~17 degrees threshold
		# Stop animations and mark as complete
		animation_duration = get_progress()
		simple_torso.stop()
		parent_behaviour.legs.simple_animator.stop()
		return
	
	if acts_less_than(rotation_period):
		player.rotate_y(overrotation * delta / rotation_period)
