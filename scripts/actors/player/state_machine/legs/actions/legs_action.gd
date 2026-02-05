extends Node
class_name LegsAction

var player : Player
var player_aim : PlayerAim
var skeleton : Skeleton3D
var combat : HumanoidCombat
var legs : LegsMachine
var legs_anim_settings : AnimationPlayer
var torso_anim_settings : AnimationPlayer

@export var action_name : String
@export var anim_settings : String = "simple"
@export var legs_animator : SkeletonModifier3D
@export var motion_type : LegsMachine.MotionType

var enter_action_time : float

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _update(input : InputPackage, delta : float):
	update(input, delta)
	legs.last_y_speed = player.velocity.y

func update(_input : InputPackage, _delta : float):
	pass

func seek_land(delta : float):
	if not player.is_on_floor():
		player.velocity.y = legs.last_y_speed - gravity * delta

# heirs use different animation modifiers, so we need per child definitions
func setup_animator(_previous_action : LegsAction, _input : InputPackage):
	pass


func _on_enter_action(input : InputPackage):
	mark_enter_action()
	on_enter_action(input)


func on_enter_action(_input : InputPackage):
	pass


func on_exit_action():
	pass


#func get_loco_vector(input : InputPackage) -> Vector2:
	#var vector : Vector2
	#if combat.current_camera_mode == combat.CameraMode.FREE:
		#vector = input.get_vector2()
	#else:
		#vector = input.get_vector2().rotated(player.basis.z.signed_angle_to(camera.basis.z, Vector3.UP))
	#return vector

func animation_ended() -> bool:
	return false

#region Time Measurements
func mark_enter_action():
	enter_action_time = Time.get_unix_time_from_system()

func get_progress() -> float:
	var now = Time.get_unix_time_from_system()
	return now - enter_action_time

func acts_longer_than(time : float) -> bool:
	return get_progress() >= time

func acts_less_than(time : float) -> bool:
	return get_progress() < time

func acts_between(start : float, finish : float) -> bool:
	var progress = get_progress()
	return progress >= start and progress <= finish
#endregion
