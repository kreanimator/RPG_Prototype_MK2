extends TorsoAction

var hit_action_mapper: Dictionary = {
	"punch": ["Punch_Cross", "Punch_Jab"],
	"kick": ["Kick"]
	#"punch": ["anim_pack_2/Melee_Hook", "anim_pack_2/Melee_Uppercut"],
	#"kick": ["Kick", "anim_pack_2/Melee_Knee"]
}

var _hit_processed: bool = false
var _cached_target: Actor = null
var _cached_target_position: Vector3 = Vector3.ZERO

func setup_animator(_input : InputPackage):
	animation = get_current_animation()
	if torso_anim_settings.current_animation == "simple": # ie both are simple of AnimatorModifier type
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0)
		torso_anim_settings.play("simple", 0.15)
	
	if parent_behaviour.legs.legs_anim_settings.current_animation == "simple": # ie both are simple of AnimatorModifier type
		parent_behaviour.legs.simple_animator.play(animation, 0.15)
	else:
		parent_behaviour.legs.simple_animator.play(animation, 0)
		parent_behaviour.legs.legs_anim_settings.play("simple", 0.15)
	
	_hit_processed = false
	
	# Get cached target from parent behaviour (cached before AP was spent)
	if parent_behaviour.has_method("_get_cached_attack_target"):
		var cached = parent_behaviour._get_cached_attack_target()
		if cached != null:
			_cached_target = cached["target"]
			_cached_target_position = cached["position"]
	
	# Also try to cache from resolver as fallback
	if _cached_target == null:
		_cache_target()

func _cache_target() -> void:
	var resolver := player.player_model.action_resolver as ActionResolver
	if resolver == null or resolver.current_intent == null:
		return
	
	if resolver.current_intent.intent_type != ActionIntent.IntentType.ATTACK:
		return
	
	var target := resolver.current_intent.target_object as Actor
	if target != null and is_instance_valid(target):
		_cached_target = target
		_cached_target_position = target.global_position

func update(_input : InputPackage, _delta : float):
	# Process hit once when action starts (after a short delay to match animation timing)
	if not _hit_processed and acts_longer_than(0.1):  # Small delay to match animation
		_process_unarmed_hit()
		_hit_processed = true

func _process_unarmed_hit() -> void:
	# Use cached target if available (in case intent was cleared)
	var target: Actor = null
	var target_position: Vector3 = Vector3.ZERO
	
	if _cached_target != null and is_instance_valid(_cached_target):
		target = _cached_target
		target_position = _cached_target_position
	else:
		# Fallback: try to get from resolver
		var resolver := player.player_model.action_resolver as ActionResolver
		if resolver != null and resolver.current_intent != null:
			if resolver.current_intent.intent_type == ActionIntent.IntentType.ATTACK:
				target = resolver.current_intent.target_object as Actor
				if target != null and is_instance_valid(target):
					target_position = target.global_position
	
	if target == null or not is_instance_valid(target):
		return
	
	# Get unarmed action type and damage
	var stats := player.player_model.stats_manager as StatsManager
	var unarmed_action := stats.get_unarmed_action_key()
	var damage_range := _get_unarmed_damage_range(unarmed_action)
	var damage := float(randi_range(damage_range[0], damage_range[1]))
	
	# Calculate hit chance (no weapon = unarmed)
	var hit_result := CombatCalculator.calculate_and_roll_hit(player, target, null)
	
	if not hit_result["hit"]:
		# Show MISS indicator - use cached position
		DamageIndicator.create_at_position(target_position, DamageIndicator.IndicatorType.MISS)
		return
	
	# Attack hit - apply damage
	var target_resources := CombatCalculator.get_actor_resources(target)
	if target_resources != null:
		target_resources.take_damage(damage)

func get_current_animation() -> String:
	var stats := player.player_model.stats_manager as StatsManager
	var key := stats.get_unarmed_action_key()
	var options: Array = hit_action_mapper.get(key)

	if options.size() == 1:
		return options[0]

	return options[randi() % options.size()]

func _get_unarmed_damage_range(action: String) -> Array:
	match action:
		"punch":
			return [3, 7]  # min, max
		"kick":
			return [4, 10]  # min, max
		_:
			return [3, 7]  # default to punch
