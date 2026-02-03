extends LegsAction

@export var animation : String = "walk"

var cycle_spectre : Dictionary = {
	Vector2(0, 1) : "_n",
	Vector2(-1, 0) : "_w", 
	Vector2(0, -1) : "_s",
	Vector2(1, 0) : "_e",
}

func _ready():
	for key in cycle_spectre.keys():
		cycle_spectre[key] = animation + cycle_spectre[key]

func update(input : InputPackage, delta : float) -> void:
	# Point-and-click movement is handled by the main player controller
	# We just need to update the animation direction
	var movement_dir = Vector2(player.velocity.x, player.velocity.z).normalized()
	if movement_dir.length() > 0.1:
		legs_animator.set_input_vector(movement_dir)

func setup_animator(previous_action : LegsAction, _input : InputPackage):
	if previous_action.anim_settings == anim_settings:
		legs_animator.transition(cycle_spectre, 0.15)
	else:
		legs_animator.transition(cycle_spectre, 0)
		legs_anim_settings.play(anim_settings, 0.15)