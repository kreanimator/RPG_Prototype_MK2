extends Node

signal game_state_changed(new_state: int, reason: String)

enum GameState { INVESTIGATION, COMBAT }
enum MoveMode { WALK, RUN, CROUCH }
enum MouseMode { MOVE, ATTACK, INVESTIGATE, INTERACT }

var game_state: GameState = GameState.INVESTIGATION:
	set(value):
		if value == game_state:
			return
		game_state = value
		print("GameState changed to:",
			GameState.keys()[game_state],
			"reason:",
			_last_reason)
		game_state_changed.emit(game_state, _last_reason)

var move_mode: MoveMode = MoveMode.RUN
var mouse_mode: MouseMode = MouseMode.MOVE

var _last_reason: String = "init"

func enter_combat(reason: String = "unknown") -> void:
	_last_reason = reason
	game_state = GameState.COMBAT

func exit_combat(reason: String = "unknown") -> void:
	_last_reason = reason
	game_state = GameState.INVESTIGATION

func toggle_combat(reason: String = "ui_toggle") -> void:
	if game_state == GameState.COMBAT:
		exit_combat(reason)
	else:
		enter_combat(reason)

func is_in_combat() -> bool:
	return game_state == GameState.COMBAT
