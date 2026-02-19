extends Node
class_name HumanoidCombat

# Model can be either PlayerModel or HumanoidModel
var model: Node  # PlayerModel or HumanoidModel

# TODO on call nodes/resources talk
@export var resources : ActorResources

@onready var weapon_socket_b : Node3D = $"../Back/WeaponSocketB"
@onready var weapon_socket_ra : Node3D = $"../RightWrist/WeaponSocketRA"
var active_weapon: Weapon

func _ready() -> void:
	# Auto-detect model from parent (works for both PlayerModel and HumanoidModel)
	model = get_parent()
static var melee_attacks : Dictionary = {
	"light_attack_pressed" : "slash_1",
}

#static var aim_attacks : Dictionary = {
	#"light_attack_pressed" : "slash_1",
#}

var weapon_holstered : bool = false


	
func contextualize(new_input) -> InputPackage:
	# Accept both InputPackage and AIInputPackage (AIInputPackage extends InputPackage)
	translate_inputs(new_input)
	
	# TODO wrap function maybe
	if new_input.actions.has("holster_weapon"):
		if weapon_holstered:
			new_input.behaviour_names.append("take_weapons")
		else:
			new_input.behaviour_names.append("hide_weapons")
	
	# Safely access active_weapon from model (works for both PlayerModel and HumanoidModel)
	if model != null:
		# Use get() which returns null if property doesn't exist
		var weapon = model.get("active_weapon")
		active_weapon = weapon if is_instance_valid(weapon) else null
	else:
		active_weapon = null
	
	
	return new_input


func translate_inputs(input : InputPackage):
	if not input.combat_actions.is_empty():
		# Safely access active_weapon from model (works for both PlayerModel and HumanoidModel)
		if model != null:
			# Use get() which returns null if property doesn't exist
			var weapon = model.get("active_weapon")
			active_weapon = weapon if is_instance_valid(weapon) else null
		else:
			active_weapon = null
		if not (active_weapon is RangedWeapon):
			for action in input.combat_actions:
				# Only process actions that exist in melee_attacks dictionary
				# light_attack_held is only for ranged weapons, skip it for melee
				if melee_attacks.has(action):
					input.behaviour_names.append(melee_attacks[action])
