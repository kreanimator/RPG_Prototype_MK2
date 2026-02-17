extends Actor
class_name Player

const LIGHT_OBJECT_BOOST: float = 3.0
const MIN_MASS_RATIO: float = 0.1

@export var camera_node: Node3D
@export var debug_turns: bool = true

@onready var player_input: InputCollector = $InputController
@onready var player_model: PlayerModel = $PlayerModel
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var stats_manager: StatsManager = $StatsManager
@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var player_visuals: PlayerVisuals = $PlayerVisuals

var is_player_turn: bool = false
var _tc: TurnController

# guard so we don't finish twice from repeated out_of_ap signals / spam
var _ending_turn: bool = false


func _ready() -> void:
	super._ready()

	setup_visuals()
	setup_model()
	setup_inventory()
	set_nav_agent()
	faction_component.faction = faction_component.Faction.PLAYER

	call_deferred("_bind_turn_controller")


func _physics_process(delta: float) -> void:
	var input := player_input.collect_input()
	player_model.update(input, delta)
	input.queue_free()
	_push_rigid_bodies()


func setup_model() -> void:
	stats_manager.set_model(player_model)


func setup_inventory() -> void:
	inventory_manager.set_stats_manager(stats_manager)
	stats_manager.set_inventory_manager(inventory_manager)

	equipment_manager.set_stats_manager(stats_manager)
	equipment_manager.set_inventory_manager(inventory_manager)
	equipment_manager.set_player_model(player_model)
	stats_manager.set_equipment_manager(equipment_manager)

	equipment_manager.equipment_changed.connect(_on_equipment_changed)
	equipment_manager.weapon_equipped.connect(_on_weapon_equipped)
	equipment_manager.weapon_unequipped.connect(_on_weapon_unequipped)
	equipment_manager.active_slot_changed.connect(_on_active_slot_changed)


func setup_visuals() -> void:
	player_visuals.accept_model(player_model)


func _bind_turn_controller() -> void:
	_tc = get_tree().get_first_node_in_group("turn_controller") as TurnController
	assert(_tc != null)

	# connect once
	if not _tc.active_actor_changed.is_connected(_on_active_actor_changed):
		_tc.active_actor_changed.connect(_on_active_actor_changed)

	if debug_turns:
		print("[Player] bound TC. current_actor=", _dbg_actor(_tc.current_actor))

	# sync immediately (important when combat starts before player binds)
	_on_active_actor_changed(_tc.current_actor)


# TurnController calls these every action slot
func on_turn_started(_turn_controller: Node) -> void:
	is_player_turn = true
	_ending_turn = false

	if debug_turns:
		print("[Player] on_turn_started  is_player_turn=", is_player_turn, " tc_current=", _dbg_actor(_tc.current_actor))

	player_model.resources.restore_action_points_full()

	# connect for this slot
	if not player_model.resources.out_of_ap.is_connected(_on_out_of_ap):
		player_model.resources.out_of_ap.connect(_on_out_of_ap)


func on_turn_ended(_turn_controller: Node) -> void:
	if debug_turns:
		print("[Player] on_turn_ended    is_player_turn=", is_player_turn, " tc_current=", _dbg_actor(_tc.current_actor))

	is_player_turn = false
	_ending_turn = false

	if player_model.resources.out_of_ap.is_connected(_on_out_of_ap):
		player_model.resources.out_of_ap.disconnect(_on_out_of_ap)


func _on_out_of_ap() -> void:
	# IMPORTANT: never gate on is_player_turn
	# Out_of_ap is "player AP reached 0" and stop nav already happened in resources.
	if _ending_turn:
		return
	_ending_turn = true

	if debug_turns:
		_dbg_nav("[Player] out_of_ap -> defer finish_turn")

	call_deferred("finish_turn")


func _on_active_actor_changed(actor: Actor) -> void:
	is_player_turn = (actor == self)

	if debug_turns:
		print("[Player] active_actor_changed -> is_player_turn=", is_player_turn,
			" actor=", _dbg_actor(actor),
			" tc_current=", _dbg_actor(_tc.current_actor))


# ---- Debug helpers ----
func _dbg_actor(a: Actor) -> String:
	if a == null:
		return "null"
	return "%s(%s)" % [a.name, a.get_class()]

func _dbg_nav(prefix: String) -> void:
	# these should exist; if not, crash so you can fix wiring
	assert(nav_agent != null)
	print(prefix, " pos=", global_position, " target=", nav_agent.target_position, " finished=", nav_agent.is_navigation_finished())


# -------------------------
# Equipment callbacks
# -------------------------
func _on_equipment_changed() -> void:
	equipment_manager._switch_to_slot(equipment_manager.current_active_slot)

func _on_weapon_equipped(slot: String, _weapon: Weapon) -> void:
	if slot == equipment_manager.current_active_slot:
		equipment_manager._switch_to_slot(slot)

func _on_weapon_unequipped(slot: String) -> void:
	if slot == equipment_manager.current_active_slot:
		var other_slot := "WEAPON_2" if slot == "WEAPON_1" else "WEAPON_1"
		if equipment_manager.is_slot_equipped(other_slot):
			equipment_manager.switch_weapon_slot(other_slot)
		else:
			equipment_manager._switch_to_slot(slot)

func _on_active_slot_changed(slot: String) -> void:
	equipment_manager._switch_to_slot(slot)


# -------------------------
# Physics helpers
# -------------------------
func _push_rigid_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var rigid_body: RigidBody3D = c.get_collider()
			var knockback_dir := (rigid_body.global_position - global_position).normalized()
			knockback_dir.y = 0

			var player_mass := 60.0
			var mass_ratio = clamp(player_mass / rigid_body.mass, MIN_MASS_RATIO, 1.0)
			var knockback_force = 2.0 * mass_ratio

			rigid_body.apply_impulse(knockback_dir * knockback_force)


func get_resources() -> PlayerResources:
	return player_model.resources if player_model else null
