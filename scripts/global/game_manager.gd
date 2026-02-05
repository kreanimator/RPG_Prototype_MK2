extends Node

enum GameState {INVESTIGATION, COMBAT}
enum MoveMode {WALK, RUN, CROUCH}

var game_state: GameState = GameState.INVESTIGATION
var move_mode: MoveMode = MoveMode.RUN
