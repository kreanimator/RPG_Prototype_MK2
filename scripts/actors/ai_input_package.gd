extends InputPackage
class_name AIInputPackage

# AI Input Package - extends InputPackage for actors (NPCs, enemies)
# This allows AI to control actors without interfering with player input
# Each actor gets its own AIInputPackage instance, preventing state switching for all actors
# Since it extends InputPackage, it's compatible with all existing state machine code

# AI-specific fields
var target_position: Vector3 = Vector3.ZERO
var has_target_position: bool = false
var move_direction: Vector3 = Vector3.ZERO  # For AI movement direction

