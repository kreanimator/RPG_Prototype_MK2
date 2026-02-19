extends TorsoBehaviourNPC

var animation: String = "Midair"

@export_range(0.1, 2.0, 0.1) var gravity_multiplier: float = 1.2
const MOMENTUM_DECAY: float = 0.9  # Horizontal momentum decay when input is released

var initial_horizontal_speed: float = 0.0
var initial_horizontal_direction: Vector3 = Vector3.ZERO

func transition_logic(input : AIInputPackage) -> String:
	map_with_dictionary(input)
	
	if actor.is_on_floor():
		# When landing, transition to idle (NPCs don't have input_direction like players)
		return "idle"
	return "okay"

func update(_input : AIInputPackage, delta : float):
	if not actor.is_on_floor():
		actor.velocity += Vector3(0, -gravity, 0) * delta * gravity_multiplier
	
	_preserve_momentum()
	actor.move_and_slide()

func _preserve_momentum():
	if initial_horizontal_speed > 0.1 and initial_horizontal_direction.length() > 0.1:
		var preserved_speed = initial_horizontal_speed * MOMENTUM_DECAY
		actor.velocity.x = initial_horizontal_direction.x * preserved_speed
		actor.velocity.z = initial_horizontal_direction.z * preserved_speed
	else:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0

func on_enter_behaviour(_input : AIInputPackage):
	# Preserve momentum from jump_up behavior (if we add it later)
	# Capture current horizontal velocity as initial momentum
	var horizontal_velocity = Vector3(actor.velocity.x, 0, actor.velocity.z)
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

func setup_legs_animator(previous_action : LegsActionNPC, _input : AIInputPackage):
	if previous_action.anim_settings == "simple":
		legs.simple_animator.play(animation, 0.15)
	else:
		legs.simple_animator.play(animation, 0)
		legs.legs_anim_settings.play("simple", 0.15)

func on_exit_behaviour():
	initial_horizontal_speed = 0.0
	initial_horizontal_direction = Vector3.ZERO
