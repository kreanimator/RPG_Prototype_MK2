extends Node

enum GameState {INVESTIGATION, COMBAT}
enum MoveMode {WALK, RUN, CROUCH}
enum MouseMode { MOVE, ATTACK, INVESTIGATE }

var game_state: GameState = GameState.INVESTIGATION
var move_mode: MoveMode = MoveMode.RUN
var mouse_mode: MouseMode = MouseMode.MOVE
