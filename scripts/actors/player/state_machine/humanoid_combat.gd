extends Node
class_name HumanoidCombat

@onready var model = $".." as PlayerModel

# TODO on call nodes/resources talk
@export var resources : PlayerResources

@onready var weapon_socket_b : Node3D = $"../Back/WeaponSocketB"
@onready var weapon_socket_ra : Node3D = $"../RightWrist/WeaponSocketRA"
var active_weapon: Weapon
static var melee_attacks : Dictionary = {
	"light_attack_pressed" : "slash_1",
}

#static var aim_attacks : Dictionary = {
	#"light_attack_pressed" : "slash_1",
#}

var weapon_holstered : bool = false
var aim_mode_on : bool = false
var is_precise_aim : bool = false

	
func contextualize(new_input : InputPackage) -> InputPackage:
	translate_inputs(new_input)
	
	# TODO wrap function maybe
	if new_input.actions.has("holster_weapon"):
		if weapon_holstered:
			new_input.behaviour_names.append("take_weapons")
		else:
			new_input.behaviour_names.append("hide_weapons")
	active_weapon = model.active_weapon if is_instance_valid(model.active_weapon) else null
	
	# Reset aim mode if weapon is invalid or not a ranged weapon
	if aim_mode_on and (active_weapon == null or not (active_weapon is RangedWeapon)):
		aim_mode_on = false
		is_precise_aim = false
		# Sync with player aim system
		if model.player_aim:
			model.player_aim.is_precise_aim = false
	
	if new_input.actions.has("toggle_aim_mode") and active_weapon != null and active_weapon is RangedWeapon:
		if not aim_mode_on:
			# Entering aim mode - turn off aim line and reset precise aim
			aim_mode_on = true
			is_precise_aim = false
			# Sync with player aim system
			if model.player_aim:
				model.player_aim.is_precise_aim = false
		else:
			# Already aiming, toggle again - exit aim mode
			aim_mode_on = false
			is_precise_aim = false
			# Sync with player aim system
			if model.player_aim:
				model.player_aim.is_precise_aim = false
		
	
	# Handle precise aim toggle separately (only when already aiming)
	if new_input.aim_actions.has("toggle_precise_aim_mode") and aim_mode_on and active_weapon != null and active_weapon is RangedWeapon:
		is_precise_aim = !is_precise_aim
		# Sync with player aim system
		if model.player_aim:
			model.player_aim.is_precise_aim = is_precise_aim
	
	if aim_mode_on:
		new_input.behaviour_names.append("aim")
	
	return new_input


func translate_inputs(input : InputPackage):
	if not input.combat_actions.is_empty():
		active_weapon = model.active_weapon if is_instance_valid(model.active_weapon) else null
		if not aim_mode_on and active_weapon != null and not (active_weapon is RangedWeapon):
			for action in input.combat_actions:
				# Only process actions that exist in melee_attacks dictionary
				# light_attack_held is only for ranged weapons, skip it for melee
				if melee_attacks.has(action):
					input.behaviour_names.append(melee_attacks[action])
