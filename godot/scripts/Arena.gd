class_name Arena
extends Node2D

const ARENA_RECT := Rect2(Vector2(80, 60), Vector2(1120, 600))
const VIEW_RECT := Rect2(Vector2.ZERO, Vector2(1280, 720))
const BLUE_GUIDES_BG := preload("res://assets/arena/arena_blue_guides_bg.png")

func _draw() -> void:
	draw_texture_rect(BLUE_GUIDES_BG, VIEW_RECT, false, Color(1.0, 1.0, 1.0, 0.82))
	draw_rect(VIEW_RECT, Color(0.008, 0.008, 0.014, 0.26))
	draw_rect(ARENA_RECT, Color(0.055, 0.052, 0.070, 0.34))
	_draw_floor_grid()
	_draw_border()


func _draw_floor_grid() -> void:
	var minor_color := Color(0.13, 0.13, 0.18, 0.22)
	var major_color := Color(0.20, 0.19, 0.26, 0.28)
	for x in range(int(ARENA_RECT.position.x), int(ARENA_RECT.end.x) + 1, 40):
		var color := major_color if (x - int(ARENA_RECT.position.x)) % 160 == 0 else minor_color
		draw_line(Vector2(x, ARENA_RECT.position.y), Vector2(x, ARENA_RECT.end.y), color, 1.0)
	for y in range(int(ARENA_RECT.position.y), int(ARENA_RECT.end.y) + 1, 40):
		var color := major_color if (y - int(ARENA_RECT.position.y)) % 160 == 0 else minor_color
		draw_line(Vector2(ARENA_RECT.position.x, y), Vector2(ARENA_RECT.end.x, y), color, 1.0)

	# A few dim floor scars keep motion readable without looking interactive.
	for i in range(28):
		var seed_x := int((i * 137) % int(ARENA_RECT.size.x))
		var seed_y := int((i * 71) % int(ARENA_RECT.size.y))
		var pos := ARENA_RECT.position + Vector2(seed_x, seed_y)
		draw_rect(Rect2(pos, Vector2(22 + (i % 3) * 12, 2)), Color(0.018, 0.017, 0.026, 0.55))


func _draw_border() -> void:
	var outer := ARENA_RECT.grow(24.0)
	draw_rect(outer, Color(0.025, 0.024, 0.038), false, 28.0)
	draw_rect(ARENA_RECT, Color(0.24, 0.23, 0.33), false, 4.0)
	draw_rect(ARENA_RECT.grow(-12.0), Color(0.09, 0.085, 0.12), false, 2.0)

	var cap_color := Color(0.055, 0.052, 0.075)
	for x in range(110, 1180, 110):
		draw_rect(Rect2(Vector2(x, 42), Vector2(54, 28)), cap_color)
		draw_rect(Rect2(Vector2(x + 45, 650), Vector2(54, 28)), cap_color)
	for y in range(100, 620, 110):
		draw_rect(Rect2(Vector2(52, y), Vector2(28, 54)), cap_color)
		draw_rect(Rect2(Vector2(1200, y + 45), Vector2(28, 54)), cap_color)
