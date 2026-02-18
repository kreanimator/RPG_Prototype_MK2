extends RangedWeapon


func _ready() -> void:
	super._ready()
	socket_position = Vector3(0.046,0.094,0.037)
	socket_rotation = Vector3(deg_to_rad(-11.3), deg_to_rad(79.8), deg_to_rad(-178.8))
