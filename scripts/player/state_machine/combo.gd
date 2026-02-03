extends Node
class_name Combo

@onready var move : State 
@export var triggered_move : String

func is_triggered(_input : InputPackage) -> bool:
	return false
