class_name ExitGate
extends Sprite2D

const SOURCE_OPENING_WIDTH := 360.0


func configure(door_rect: Rect2) -> void:
	var uniform_scale := door_rect.size.x / SOURCE_OPENING_WIDTH
	global_position = Vector2(door_rect.get_center().x, door_rect.position.y)
	scale = Vector2.ONE * uniform_scale


func set_open(is_open: bool) -> void:
	frame = 1 if is_open else 0
