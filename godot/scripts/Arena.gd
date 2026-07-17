class_name Arena
extends Node2D

const ARENA_RECT := Rect2(Vector2(80, 60), Vector2(1120, 600))
const VIEW_RECT := Rect2(Vector2.ZERO, Vector2(1280, 720))
const BACKGROUNDS := {
	"blue_guides": preload("res://assets/arena/arena_blue_guides_bg.png"),
	"red_fault": preload("res://assets/arena/arena_red_fault_bg.png"),
	"gold_boss": preload("res://assets/arena/arena_gold_boss_bg.png"),
}

var _background: Texture2D = BACKGROUNDS["blue_guides"]


func set_background(background_id: String) -> void:
	if not BACKGROUNDS.has(background_id):
		push_warning("Unknown arena background: %s" % background_id)
		background_id = "blue_guides"
	_background = BACKGROUNDS[background_id]
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(_background, VIEW_RECT, false)
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
	draw_rect(ARENA_RECT, Color(0.0, 0.0, 0.0, 0.96), false, 5.0)
