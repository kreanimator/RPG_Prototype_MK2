extends TorsoBehaviour

@export var animation: String = "Midair"

@export_range(0.1, 2.0, 0.1) var gravity_multiplier: float = 1.2
const MOMENTUM_DECAY: float = 0.9  # Horizontal momentum decay when input is released

var initial_horizontal_speed: float = 0.0
var initial_horizontal_direction: Vector3 = Vector3.ZERO

func transition_logic(input : InputPackage) -> String:
	map_with_dictionary(input)
	
	if player.is_on_floor():
		if input.input_direction.length() < 0.1:
			return "idle"
		else:
			return "run"
	return "okay"

func update(_input : InputPackage, delta : float):
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta * gravity_multiplier
	
	_preserve_momentum()
	player.move_and_slide()

func _preserve_momentum():
	if initial_horizontal_speed > 0.1 and initial_horizontal_direction.length() > 0.1:
		var preserved_speed = initial_horizontal_speed * MOMENTUM_DECAY
		player.velocity.x = initial_horizontal_direction.x * preserved_speed
		player.velocity.z = initial_horizontal_direction.z * preserved_speed
	else:
		player.velocity.x = 0.0
		player.velocity.z = 0.0

func on_enter_behaviour(_input : InputPackage):
	# Preserve momentum from jump_up behavior
	# Capture current horizontal velocity as initial momentum
	var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
	initial_horizontal_speed = horizontal_velocity.length()
	if initial_horizontal_speed > 0.1:
		initial_horizontal_direction = horizontal_velocity.normalized()
	else:
		initial_horizontal_speed = 0.0
		initial_horizontal_direction = Vector3.ZERO
	
	# Play midair animation
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)

func setup_legs_animator(previous_action : LegsAction, _input : InputPackage):
	if previous_action.anim_settings == "simple":
		legs.simple_animator.play(animation, 0.15)
	else:
		legs.simple_animator.play(animation, 0)
		legs.legs_anim_settings.play(animation, 0.15)

func on_exit_behaviour():
	initial_horizontal_speed = 0.0
	initial_horizontal_direction = Vector3.ZERO
