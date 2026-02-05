extends Node3D
class_name PlayerVisuals

@onready var model : PlayerModel
@onready var cursor_manager: CursorManager = $CursorManager
@onready var mouse_debug_overlay: MouseDebugOverlay = $UI/MouseDebugOverlay

#@onready var hp_bar: ProgressBar = $UI/HP_BAR
#@onready var stamina_bar: ProgressBar = $UI/STAMINA_BAR
#@onready var ammo_debug_label: Label = $UI/AmmoDebug/Panel/AmmoDebugLabel
#@onready var inventory: InventoryUI = $UI/Inventory
func bind_mouse_interactor(interactor: MouseInteractor) -> void:
	cursor_manager.bind(interactor)
	mouse_debug_overlay.set_mousw_interactor(interactor)

func accept_model(_model : PlayerModel) -> void:
	model = _model
	for child in get_children():
		if child is MeshInstance3D:
			child.skeleton = _model.skeleton.get_path()
	#call_deferred("setup_ui_bars")

#func setup_ui_bars() -> void:
	#if model and model.resources:
		#hp_bar.max_value = model.resources.max_health
		#stamina_bar.max_value = model.resources.max_stamina


func _process(_delta: float) -> void:
	pass
	#update_resources_interface()
	#update_ammo_display()

#func update_ammo_display() -> void:
	#var current_weapon = model.active_weapon
	#if is_instance_valid(current_weapon) and current_weapon is RangedWeapon:
		#var ranged_weapon = current_weapon as RangedWeapon
		#var ammo_in_inventory = ranged_weapon.get_ammo_in_inventory()
		#ammo_debug_label.text = "%d/%d" % [ranged_weapon.current_ammo, ammo_in_inventory]
	#else:
		#ammo_debug_label.text = ""
#
#func update_resources_interface() -> void:
	#assert(model != null, "model is null!")
	#assert(model.resources != null, "model.resources is null!")
	#assert(hp_bar != null, "hp_bar is null!")
	#assert(stamina_bar != null, "stamina_bar is null!")
	#
	##if not model.is_enemy:
	#hp_bar.value = clamp(model.resources.health, 0.0, model.resources.max_health)
	#stamina_bar.value = clamp(model.resources.stamina, 0.0, model.resources.max_stamina)

#func toggle_inventory() -> void:
	#inventory.visible = !inventory.visible
	#if inventory.visible:
		#inventory._print_inventory_state()
		#inventory._refresh_inventory()
