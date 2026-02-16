extends Node
class_name TurnController

signal round_changed(round_number: int)
signal active_actor_changed(actor: Actor)

@export var actor_group: String = "actors"
@export var team_player_group: String = "team_player"
@export var team_enemy_group: String = "team_enemy"

# Debug toggles
@export var debug_turns: bool = true
@export var debug_roster: bool = true
@export var debug_end_conditions: bool = true

var round_number: int = 1
var current_actor: Actor = null
var actors_list: Array[Actor] = []
var _index: int = -1
var _running: bool = false

func _ready() -> void:
	add_to_group("turn_controller")
	if debug_turns:
		print("[TurnController] _ready()")
	reset()
	populate_actors()

func start_combat() -> void:
	if debug_turns:
		print("[TurnController] start_combat()")
	reset()
	populate_actors()

	_running = true

	if debug_roster:
		print("[TurnController] Combat roster size=", actors_list.size(), " actors=", _actors_debug_list())

	_advance_to_next_actor()

func end_combat() -> void:
	if debug_turns:
		print("[TurnController] end_combat() running=", _running, " current_actor=", _actor_dbg(current_actor), " round=", round_number)
	_running = false
	_disconnect_from_current_actor()
	current_actor = null

func populate_actors() -> void:
	actors_list.clear()
	var nodes := get_tree().get_nodes_in_group(actor_group)

	if debug_roster:
		print("[TurnController] populate_actors() nodes_in_group('", actor_group, "')=", nodes.size())

	for n in nodes:
		if n is Actor:
			actors_list.append(n)

	if debug_roster:
		print("[TurnController] populate_actors() -> actors_list size=", actors_list.size(), " actors=", _actors_debug_list())

func reset() -> void:
	if debug_turns:
		print("[TurnController] reset()")
	_running = false
	round_number = 1
	_index = -1
	_disconnect_from_current_actor()
	current_actor = null
	actors_list.clear()

# UI calls this (your End Turn button)
func end_current_actor_turn() -> void:
	if not _running or current_actor == null:
		if debug_turns:
			print("[TurnController] end_current_actor_turn() ignored. running=", _running, " current_actor=", _actor_dbg(current_actor))
		return

	if debug_turns:
		print("[TurnController] end_current_actor_turn() actor=", _actor_dbg(current_actor), " round=", round_number, " index=", _index)

	# Let actor clean up
	current_actor.on_turn_ended(self)
	_disconnect_from_current_actor()

	current_actor = null

	# Optional: victory/defeat check (very basic)
	var result := _check_end_conditions()
	if result != "":
		if debug_end_conditions:
			print("[TurnController] Combat ended by end condition: ", result)
		end_combat()
		return

	_advance_to_next_actor()

func _advance_to_next_actor() -> void:
	if not _running:
		if debug_turns:
			print("[TurnController] _advance_to_next_actor() ignored (not running)")
		return

	if actors_list.is_empty():
		if debug_turns:
			print("[TurnController] _advance_to_next_actor() -> no actors, ending combat")
		end_combat()
		return

	var tries := 0
	if debug_turns:
		print("[TurnController] _advance_to_next_actor() start. round=", round_number, " index=", _index, " roster=", actors_list.size())

	while tries < actors_list.size():
		_index = (_index + 1) % actors_list.size()
		tries += 1

		# Round increments when we wrap to first index again
		if _index == 0:
			if round_number > 1: # don’t emit on first selection unless you want it
				if debug_turns:
					print("[TurnController] round_changed emit round=", round_number)
				round_changed.emit(round_number)
			round_number += 1
			if debug_turns:
				print("[TurnController] round_number incremented -> ", round_number)

		var a := actors_list[_index]

		if not is_instance_valid(a):
			if debug_turns:
				print("[TurnController] skip: invalid instance at index=", _index)
			continue

		if not a.can_take_turn():
			if debug_turns:
				print("[TurnController] skip: cannot_take_turn actor=", _actor_dbg(a), " index=", _index)
			continue

		if debug_turns:
			print("[TurnController] selecting actor=", _actor_dbg(a), " index=", _index, " tries=", tries)

		_set_current_actor(a)
		return

	# Nobody can act
	if debug_turns:
		print("[TurnController] _advance_to_next_actor() -> nobody eligible after tries=", tries, " ending combat")
	end_combat()

func _set_current_actor(a: Actor) -> void:
	current_actor = a

	if debug_turns:
		print("[TurnController] _set_current_actor() actor=", _actor_dbg(current_actor), " round=", round_number, " index=", _index)

	# Listen for "actor says I'm done"
	if not current_actor.turn_finished.is_connected(_on_actor_finished):
		current_actor.turn_finished.connect(_on_actor_finished)
		if debug_turns:
			print("[TurnController] connected actor.turn_finished -> _on_actor_finished for actor=", _actor_dbg(current_actor))

	# Start-of-turn hook FIRST
	current_actor.on_turn_started(self)

	# THEN notify UI / others
	active_actor_changed.emit(current_actor)

func _disconnect_from_current_actor() -> void:
	if current_actor == null:
		return

	if not is_instance_valid(current_actor):
		if debug_turns:
			print("[TurnController] _disconnect_from_current_actor() current_actor invalid")
		return

	if current_actor.turn_finished.is_connected(_on_actor_finished):
		current_actor.turn_finished.disconnect(_on_actor_finished)
		if debug_turns:
			print("[TurnController] disconnected actor.turn_finished for actor=", _actor_dbg(current_actor))

func _on_actor_finished(_actor: Actor) -> void:
	if debug_turns:
		print("[TurnController] _on_actor_finished() from actor=", _actor_dbg(_actor), " current_actor=", _actor_dbg(current_actor))
	# Actor ends itself (AI finishes, or player auto-ends on AP=0)
	end_current_actor_turn()

func _check_end_conditions() -> String:
	# Keep it minimal. You can improve later.
	var players := get_tree().get_nodes_in_group(team_player_group)
	var enemies := get_tree().get_nodes_in_group(team_enemy_group)

	if debug_end_conditions:
		print("[TurnController] _check_end_conditions() players=", players.size(), " enemies=", enemies.size())

	if players.size() == 0 or enemies.size() == 0:
		return ""

	var any_player_alive := false
	for p in players:
		if p is Actor and p.can_take_turn():
			any_player_alive = true
			break

	var any_enemy_alive := false
	for e in enemies:
		if e is Actor and e.can_take_turn():
			any_enemy_alive = true
			break

	if debug_end_conditions:
		print("[TurnController] end_conditions alive? player=", any_player_alive, " enemy=", any_enemy_alive)

	if not any_enemy_alive:
		return "victory"
	if not any_player_alive:
		return "defeat"
	return ""

# -------------------------
# Debug helpers
# -------------------------

func _actor_dbg(a: Actor) -> String:
	if a == null:
		return "null"
	if not is_instance_valid(a):
		return "INVALID"
	# prefer your exported name if set, fallback to node name
	var an := a.actor_name if "actor_name" in a else ""
	if an == "":
		an = a.name
	return "%s(%s)" % [an, a.get_class()]

func _actors_debug_list() -> String:
	var parts: Array[String] = []
	for a in actors_list:
		parts.append(_actor_dbg(a))
	return "[" + ", ".join(parts) + "]"
