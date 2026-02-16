extends Actor
class_name DummyEnemy

@export var auto_end_delay_sec: float = 10.0
@export var debug_ai: bool = true

var _tc_ref: TurnController = null
var _auto_end_token: int = 0

func on_turn_started(tc: Node) -> void:
	_tc_ref = tc as TurnController

	_auto_end_token += 1
	var token := _auto_end_token

	if debug_ai:
		print("[DummyEnemy] on_turn_started -> will finish action in ", auto_end_delay_sec, "s")

	await get_tree().create_timer(auto_end_delay_sec).timeout

	# cancelled / restarted
	if token != _auto_end_token:
		return

	# only if still valid + still its action slot
	if GameManager.game_state != GameManager.GameState.COMBAT:
		return
	if _tc_ref == null or not is_instance_valid(_tc_ref):
		return
	if _tc_ref.current_actor != self:
		return

	if debug_ai:
		print("[DummyEnemy] auto-end -> finish_turn() (end my action slot)")

	finish_turn()

func on_turn_ended(_tc: Node) -> void:
	# cancel pending timer by invalidating token
	_auto_end_token += 1
	if debug_ai:
		print("[DummyEnemy] on_turn_ended")
