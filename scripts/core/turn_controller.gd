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
var _prev_index: int = -1
var _combat_initiator: Actor = null


func _ready() -> void:
	add_to_group("turn_controller")
	if debug_turns:
		print("[TurnController] _ready()")


# -------------------------
# Public API
# -------------------------

func start_combat(initiator: Actor = null) -> void:
	if debug_turns:
		print("[TurnController] start_combat() initiator=", _actor_dbg(initiator))

	reset()

	_running = true
	_combat_initiator = initiator
	
	_build_roster()
	_recalculate_sequence_for_all_actors()

	round_number = 1
	round_changed.emit(round_number)

	_advance_to_next_actor()


func end_combat() -> void:
	if debug_turns:
		print("[TurnController] end_combat() running=", _running, " current_actor=", _actor_dbg(current_actor), " round=", round_number)

	_running = false
	_clear_current_actor()


func reset() -> void:
	_running = false
	round_number = 0
	_index = -1
	_prev_index = -1
	_combat_initiator = null
	_clear_current_actor()
	actors_list.clear()


func refresh_roster() -> void:
	var prev_current := current_actor

	_build_roster()
	_sort_actors_by_sequence()

	if debug_roster:
		_debug_print_roster()

	if not _running:
		return

	# Re-anchor index to current actor if possible
	if prev_current != null and is_instance_valid(prev_current):
		var idx := actors_list.find(prev_current)
		_index = idx if idx != -1 else -1
	else:
		_index = -1


func end_current_actor_turn() -> void:
	if not _running or current_actor == null:
		if debug_turns:
			print("[TurnController] end_current_actor_turn() ignored. running=", _running, " current_actor=", _actor_dbg(current_actor))
		return

	if debug_turns:
		print("[TurnController] end_current_actor_turn() actor=", _actor_dbg(current_actor), " round=", round_number, " index=", _index)

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
		if debug_turns:
			print("[TurnController] _advance_to_next_actor() -> no actors. staying idle (running=false)")
		_running = false
		return

	var list_size := actors_list.size()
	var tries := 0

	while tries < list_size:
		_prev_index = _index
		_index = (_index + 1) % list_size
		tries += 1

		# Detect round wrap: when we go from last index back to 0
		if _prev_index >= 0 and _prev_index == list_size - 1 and _index == 0:
			round_number += 1
			round_changed.emit(round_number)
			_recalculate_sequence_for_all_actors()
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

	# Nobody eligible: pause scheduling
	if debug_turns:
		print("[TurnController] _advance_to_next_actor() -> nobody eligible. staying idle (running=false)")
	_running = false


func _set_current_actor(a: Actor) -> void:
	current_actor = a

	if debug_turns:
		print("[TurnController] _set_current_actor() actor=", _actor_dbg(current_actor), " round=", round_number, " index=", _index)

	if not current_actor.turn_finished.is_connected(_on_actor_finished):
		current_actor.turn_finished.connect(_on_actor_finished)

	current_actor.on_turn_started(self)
	active_actor_changed.emit(current_actor)


func _clear_current_actor() -> void:
	_disconnect_from_current_actor()
	current_actor = null
	_index = -1
	_prev_index = -1


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
# Sequence Management
# -------------------------

func _build_roster() -> void:
	actors_list.clear()
	var nodes := get_tree().get_nodes_in_group(actor_group)
	for n in nodes:
		if n is Actor:
			actors_list.append(n)


func _sort_actors_by_sequence() -> void:
	actors_list.sort_custom(func(a: Actor, b: Actor) -> bool:
		return _get_actor_sequence(a) > _get_actor_sequence(b)
	)


func _get_actor_resources(actor: Actor) -> ActorResources:
	if actor is Player:
		var player := actor as Player
		return player.player_model.resources
	else:
		return actor.get_node("Resources") as ActorResources


func _get_actor_sequence(actor: Actor) -> int:
	return _get_actor_resources(actor).get_sequence()


func _recalculate_sequence_for_all_actors() -> void:
	for actor in actors_list:
		if not is_instance_valid(actor):
			continue
		
		var is_initiator := (actor == _combat_initiator)
		var resources := _get_actor_resources(actor)
		
		resources.calculate_sequence(is_initiator)
		
		if debug_turns:
			var base_seq := (resources.perception * 2) + resources.agility
			var final_seq := resources.get_sequence()
			print("[TurnController]   %s: PER=%d AGL=%d base_seq=%d initiator=%s final_seq=%d" % [
				_actor_dbg(actor),
				resources.perception,
				resources.agility,
				base_seq,
				is_initiator,
				final_seq
			])
	
	_sort_actors_by_sequence()
	
	if debug_turns:
		print("[TurnController] _recalculate_sequence_for_all_actors() initiator=", _actor_dbg(_combat_initiator))
		_debug_print_sorted_roster()


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


func _debug_print_roster() -> void:
	print("[TurnController] refresh_roster() size=", actors_list.size(), " actors=", _actors_debug_list())
	if debug_turns:
		for i in range(actors_list.size()):
			var a := actors_list[i]
			var seq := _get_actor_sequence(a)
			print("[TurnController]   [%d] %s sequence=%d" % [i, _actor_dbg(a), seq])


func _debug_print_sorted_roster() -> void:
	for i in range(actors_list.size()):
		var a := actors_list[i]
		var seq := _get_actor_sequence(a)
		print("[TurnController]   SORTED [%d] %s sequence=%d" % [i, _actor_dbg(a), seq])
