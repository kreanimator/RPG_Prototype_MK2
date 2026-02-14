extends Actor
class_name DummyEnemy

var gravity: float

func _ready() -> void:
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()
