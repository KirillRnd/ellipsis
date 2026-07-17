class_name SteelCrossbarDriven
extends Node2D

var placement_direction := Vector2.UP
var is_oriented := false


func setup(origin: Vector2, direction: Vector2, oriented: bool) -> void:
	global_position = origin
	placement_direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.UP
	is_oriented = oriented
	rotation = placement_direction.angle() + PI * 0.5
