extends Node
class_name AIInputCollector

@onready var actor: Actor = $".."

var _should_trigger_hit: bool = false
var _previous_health: float = 0.0

func _ready() -> void:
	# Wait for actor to be ready before connecting signals
	call_deferred("_setup_health_listener")

func _setup_health_listener() -> void:
	# Connect to health_changed signal to detect when damage is taken
	if actor and actor.humanoid_model and actor.humanoid_model.resources:
		actor.humanoid_model.resources.health_changed.connect(_on_health_changed)
		_previous_health = actor.humanoid_model.resources.health
		print("[AIInputCollector] Connected health_changed signal for actor: %s (initial health: %.1f)" % [actor.actor_name, _previous_health])

func collect_input() -> AIInputPackage:
	var ai_input := AIInputPackage.new()
	
	# If damage was taken, trigger hit behaviour
	if _should_trigger_hit:
		ai_input.behaviour_names.append("hit")
		_should_trigger_hit = false
	else:
		ai_input.actions.append("idle")
	
	return ai_input

func _on_health_changed(current: float, max: float) -> void:
	# Check if health decreased (damage was taken)
	if current < _previous_health:
		var damage_taken = _previous_health - current
		print("[AIInputCollector] Damage detected! Actor: %s, Damage: %.1f, Health: %.1f/%.1f" % [actor.actor_name, damage_taken, current, max])
		_should_trigger_hit = true
	_previous_health = current
