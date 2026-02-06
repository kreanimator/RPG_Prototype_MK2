extends TorsoBehaviour
class_name InteractBehaviour

# action id -> animation
var animation := {
	"pick_up": "PickUp_Kneeling",
	"pick_up_table": "PickUp_Table",
	"interact": "Interact",
}
# seconds since enter -> when to fire interaction
var action_timing := {
	"pick_up": 1.0,
	"pick_up_table": 0.4,
	"interact": 1.0,
}
var action: String
var animation_to_play: String

var _did_trigger := false
var _trigger_time := 1.0
var _target: Interactable = null
var duration: float
var aim: PlayerAim

func on_enter_behaviour(_input: InputPackage) -> void:
	if GameManager.game_state == GameManager.GameState.COMBAT:
		player.player_model.resources.spend_action_points(ap_cost)
	
	_did_trigger = false
	_prepare_action_and_anim()
	
	aim = player.player_model.player_aim as PlayerAim
	aim.set_target_node(_target, true)
	
	_trigger_time = float(action_timing.get(action, 1.0))
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation_to_play, 0.15)
	else:
		simple_torso.play(animation_to_play, 0.0)
		torso_anim_settings.play("simple", 0.15)

func transition_logic(input: InputPackage) -> String:
	map_with_dictionary(input)
	if not _did_trigger and behaves_longer_than(_trigger_time):
		_do_interaction()
		_did_trigger = true
	if behaves_longer_than(duration):
		return best_input_that_can_be_paid(input)
	return "okay"


func setup_legs_animator(previous_action: LegsAction, _input: InputPackage) -> void:
	# IMPORTANT: legs setup can be called BEFORE on_enter_behaviour,
	# so ensure we get the CURRENT target and prepare fresh animation data.
	_prepare_action_and_anim()
	
	if previous_action.anim_settings == "simple":
		legs.simple_animator.play(animation_to_play, 0.15)
	else:
		legs.simple_animator.play(animation_to_play, 0.0)
		legs.legs_anim_settings.play("simple", 0.15)


func _prepare_action_and_anim() -> void:	
	_target = player.current_interactable
	action = _get_action_from_target(_target)
	animation_to_play = String(animation.get(action))
	duration = animations_source.get_animation(animation_to_play).get_length()

func _get_action_from_target(i: Interactable) -> String:
	return String(i.default_action)

func _do_interaction() -> void:
	var t: Interactable = _target
	t.interaction_triggered.emit(player, action)

func on_exit_behaviour():
	super.on_exit_behaviour()
	# Clear target and state to prevent stale data on next interaction
	_target = null
	_did_trigger = false
	action = ""
	animation_to_play = ""
	if aim:
		aim.clear_target()
