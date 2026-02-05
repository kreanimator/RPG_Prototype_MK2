extends CharacterBody3D
class_name Player

@export var speed: float = 7.0
@export var turn_speed: float = 14.0 # higher = snappier
@export var arrive_epsilon: float = 0.15 # when we consider "arrived" to next point / target
@export var camera_node: Node3D

@onready var player_input: InputCollector = $InputController
@onready var player_model: PlayerModel = $PlayerModel
@onready var player_visuals: PlayerVisuals = $PlayerVisuals
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var stats_manager: StatsManager = $StatsManager
@onready var equipment_manager: EquipmentManager = $EquipmentManager


func _ready() -> void:
	setup_visuals()
	set_nav_agent()
#### FIXME: Need to move movement logic to states, example:
#### pass nav agent and target position to state so state machine can use it

func _physics_process(delta: float) -> void:
	var input = player_input.collect_input()
	player_model.update(input, delta)
	input.queue_free()
	## Gravity
	#if not is_on_floor():
		#velocity += get_gravity() * delta
#
	#if not nav_agent.is_navigation_finished():
		#var next: Vector3 = nav_agent.get_next_path_position()
#
		## --- FIXED ROTATION (yaw only, smooth, safe) ---
		#var to_next: Vector3 = next - global_position
		#to_next.y = 0.0
#
		## Only rotate if we have a meaningful direction
		#if to_next.length_squared() > 0.0001:
			#var target_yaw: float = atan2(to_next.x, to_next.z)
			#var t: float = 1.0 - exp(-turn_speed * delta) # frame-rate independent
			#rotation.y = lerp_angle(rotation.y, target_yaw, t)
		## --- end rotation fix ---
#
		#var direction: Vector3 = (next - global_position).normalized()
		## keep your logic; just avoid "if direction:" (Vector3 is always truthy)
		#velocity.x = direction.x * speed
		#velocity.z = direction.z * speed
	#else:
		#velocity.x = move_toward(velocity.x, 0.0, speed)
		#velocity.z = move_toward(velocity.z, 0.0, speed)
#
	#move_and_slide()

func set_target_position(pos: Vector3) -> void:
	# Snap to closest point on navmesh so agent always gets a valid target
	var map: RID = get_world_3d().navigation_map
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, pos)
	nav_agent.target_position = closest

func setup_visuals() -> void:
	player_visuals.accept_model(player_model)

func set_nav_agent():
	nav_agent.radius = 0.75
	nav_agent.path_desired_distance = 0.75
	nav_agent.target_desired_distance = 0.4
