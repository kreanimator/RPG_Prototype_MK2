extends Node
class_name TurnController

signal round_changed(round_number: int)
signal active_actor_changed(actor: Actor)

@export var actor_group: String = "actors"

# Debug toggles
@export var debug_turns: bool = true
@export var debug_roster: bool = true

var round_number: int = 0
var current_actor: Actor = null
var actors_list: Array[Actor] = []
var _index: int = -1
var _running: bool = false


func _ready() -> void:
	add_to_group("turn_controller")
	if debug_turns:
		print("[TurnController] _ready()")


# -------------------------
# Public API
# -------------------------

func start_combat() -> void:
	if debug_turns:
		print("[TurnController] start_combat()")

	reset()

	_running = true
	refresh_roster()

	# Start from round 1 on first selection
	round_number = 1
	round_changed.emit(round_number)

	_advance_to_next_actor()


func end_combat() -> void:
	if debug_turns:
		print("[TurnController] end_combat() running=", _running, " current_actor=", _actor_dbg(current_actor), " round=", round_number)

	_running = false
	_disconnect_from_current_actor()
	current_actor = null
	_index = -1


func reset() -> void:
	_running = false
	round_number = 0
	_index = -1
	_disconnect_from_current_actor()
	current_actor = null
	actors_list.clear()


# Call this if actors are spawned/removed during combat.
# Keeps current actor if still present; otherwise advances.
func refresh_roster() -> void:
	var prev_current := current_actor

	actors_list.clear()
	var nodes := get_tree().get_nodes_in_group(actor_group)
	for n in nodes:
		if n is Actor:
			actors_list.append(n)

	if debug_roster:
		print("[TurnController] refresh_roster() size=", actors_list.size(), " actors=", _actors_debug_list())

	if not _running:
		return

	# Re-anchor index to current actor if possible
	if prev_current != null and is_instance_valid(prev_current):
		var idx := actors_list.find(prev_current)
		_index = idx
		# if current actor disappeared, we'll advance on next call
	else:
		_index = actors_list.find(prev_current)


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

	_advance_to_next_actor()


# -------------------------
# Internal
# -------------------------

func _advance_to_next_actor() -> void:
	if not _running:
		if debug_turns:
			print("[TurnController] _advance_to_next_actor() ignored (not running)")
		return

	if actors_list.is_empty():
		# No actors = nothing to do. Caller decides what "combat end" means.
		if debug_turns:
			print("[TurnController] _advance_to_next_actor() -> no actors. staying idle (running=false)")
		_running = false
		_disconnect_from_current_actor()
		current_actor = null
		return

	var tries := 0
	while tries < actors_list.size():
		_index = (_index + 1) % actors_list.size()
		tries += 1

		# If we wrapped, new round
		if _index == 0 and tries > 1:
			round_number += 1
			round_changed.emit(round_number)
			if debug_turns:
				print("[TurnController] round_changed -> ", round_number)

		var a: Actor = actors_list[_index]

		if not is_instance_valid(a):
			if debug_turns:
				print("[TurnController] skip invalid actor at index=", _index)
			continue

		if not a.can_take_turn():
			if debug_turns:
				print("[TurnController] skip cannot_take_turn actor=", _actor_dbg(a))
			continue

		_set_current_actor(a)
		return

	# Nobody eligible: pause scheduling. Caller can refresh roster or end combat.
	if debug_turns:
		print("[TurnController] _advance_to_next_actor() -> nobody eligible. staying idle (running=false)")
	_running = false
	_disconnect_from_current_actor()
	current_actor = null


func _set_current_actor(a: Actor) -> void:
	current_actor = a

	if debug_turns:
		print("[TurnController] _set_current_actor() actor=", _actor_dbg(current_actor), " round=", round_number, " index=", _index)

	# Listen for "actor says I'm done"
	if not current_actor.turn_finished.is_connected(_on_actor_finished):
		current_actor.turn_finished.connect(_on_actor_finished)

	# Start-of-turn hook FIRST
	current_actor.on_turn_started(self)

	# THEN notify UI / others
	active_actor_changed.emit(current_actor)


func _disconnect_from_current_actor() -> void:
	if current_actor == null:
		return
	if not is_instance_valid(current_actor):
		return
	if current_actor.turn_finished.is_connected(_on_actor_finished):
		current_actor.turn_finished.disconnect(_on_actor_finished)


func _on_actor_finished(_actor: Actor) -> void:
	if debug_turns:
		print("[TurnController] _on_actor_finished() from actor=", _actor_dbg(_actor), " current_actor=", _actor_dbg(current_actor))
	end_current_actor_turn()


# -------------------------
# Debug helpers
# -------------------------

func _actor_dbg(a: Actor) -> String:
	if a == null:
		return "null"
	if not is_instance_valid(a):
		return "INVALID"
	var an := a.actor_name if "actor_name" in a else ""
	if an == "":
		an = a.name
	return "%s(%s)" % [an, a.get_class()]

func _actors_debug_list() -> String:
	var parts: Array[String] = []
	for a in actors_list:
		parts.append(_actor_dbg(a))
	return "[" + ", ".join(parts) + "]"
