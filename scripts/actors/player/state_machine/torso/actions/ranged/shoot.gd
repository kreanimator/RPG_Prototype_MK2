extends TorsoAction

# Shoot action for ranged weapons (replaces "hit" for consistency)
# After shooting, should switch back to idle with blending

var _shot_processed: bool = false
var _cached_target: Actor = null
var _cached_target_position: Vector3 = Vector3.ZERO

func setup_animator(_input : InputPackage):
	# Get animation name (can be set in scene or derived from weapon)
	if animation.is_empty():
		animation = "Shoot"  # Default shoot animation name
	
	if torso_anim_settings.current_animation == "simple":
		simple_torso.play(animation, 0.15)
	else:
		simple_torso.play(animation, 0.0)
		torso_anim_settings.play("simple", 0.15)
	
	if parent_behaviour.legs.legs_anim_settings.current_animation == "simple":
		parent_behaviour.legs.simple_animator.play(animation, 0.15)
	else:
		parent_behaviour.legs.simple_animator.play(animation, 0.0)
		parent_behaviour.legs.legs_anim_settings.play("simple", 0.15)
	
	_shot_processed = false
	
	# Cache target from parent behaviour
	if parent_behaviour.has_method("_get_cached_attack_target"):
		var cached = parent_behaviour._get_cached_attack_target()
		if cached != null:
			_cached_target = cached["target"]
			_cached_target_position = cached["position"]
	
	# Fallback: cache from resolver
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
	# Process shot once when action starts (after a short delay to match animation timing)
	if not _shot_processed and acts_longer_than(0.1):  # Small delay to match animation
		_process_shot()
		_shot_processed = true

func _process_shot() -> void:
	var weapon = player.player_model.active_weapon
	if not weapon is RangedWeapon:
		return
	
	var ranged_weapon = weapon as RangedWeapon
	
	# Use cached target if available
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
	
	# Get shooting direction
	var shoot_direction: Vector3
	if ranged_weapon.shooting_point:
		shoot_direction = (target_position - ranged_weapon.shooting_point.global_position).normalized()
	else:
		shoot_direction = (target_position - player.global_position).normalized()
	
	# Shoot based on weapon fire mode (for turn-based: single or burst)
	var fire_mode = ranged_weapon.fire_mode
	if fire_mode == RangedWeapon.FireMode.BURST:
		# For turn-based: fire all bullets in burst at once
		_fire_burst(ranged_weapon, shoot_direction, target_position)
	else:
		# Single shot
		ranged_weapon.shoot(shoot_direction, target_position)

func _fire_burst(weapon: RangedWeapon, direction: Vector3, target_pos: Vector3) -> void:
	# Fire all bullets in burst (for turn-based, all at once)
	# Note: In turn-based, we fire all bullets immediately for simplicity
	# Visual effect can be handled by the bullet system
	for i in range(weapon.burst_size):
		if weapon.current_ammo <= 0:
			break
		weapon.shoot(direction, target_pos)

