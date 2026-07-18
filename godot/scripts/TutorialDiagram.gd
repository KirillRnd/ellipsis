class_name TutorialDiagram
extends Control

const PLAYER_TEXTURE := preload("res://assets/actors/colorless/colorless_idle_sheet.png")
const RESONATOR_TEXTURE := preload("res://assets/actors/resonator_crystal_base.png")
const CROSSBAR_TEXTURE := preload("res://assets/items/steel_crossbar_topdown.png")
const KEY_W := preload("res://assets/ui/input_prompts/keyboard_w.png")
const KEY_A := preload("res://assets/ui/input_prompts/keyboard_a.png")
const KEY_S := preload("res://assets/ui/input_prompts/keyboard_s.png")
const KEY_D := preload("res://assets/ui/input_prompts/keyboard_d.png")
const KEY_SPACE := preload("res://assets/ui/input_prompts/keyboard_space.png")
const KEY_E := preload("res://assets/ui/input_prompts/keyboard_e.png")
const MOUSE_LEFT := preload("res://assets/ui/input_prompts/mouse_left.png")
const MOUSE_RIGHT := preload("res://assets/ui/input_prompts/mouse_right.png")

const RED := Color(0.92, 0.08, 0.14, 0.88)
const BLUE := Color(0.20, 0.67, 1.0, 0.90)
const VIOLET := Color(0.61, 0.26, 1.0, 0.92)
const SAFE := Color(0.91, 0.90, 0.87, 0.94)

var diagram_kind := ""


func set_diagram_kind(kind: String) -> void:
	diagram_kind = kind
	queue_redraw()


func _draw() -> void:
	match diagram_kind:
		"movement":
			_draw_movement()
		"safe_gap":
			_draw_safe_gap()
		"resonator":
			_draw_resonator()
		"blue_violet":
			_draw_blue_violet()
		"violet_pair":
			_draw_violet_pair()
		"crossbar":
			_draw_crossbar()


func _draw_movement() -> void:
	_draw_player(Vector2(520, 205))
	_draw_prompt(KEY_W, Rect2(105, 100, 54, 54))
	_draw_prompt(KEY_A, Rect2(48, 157, 54, 54))
	_draw_prompt(KEY_S, Rect2(105, 157, 54, 54))
	_draw_prompt(KEY_D, Rect2(162, 157, 54, 54))
	_draw_prompt(KEY_SPACE, Rect2(48, 235, 168, 54))
	draw_arc(Vector2(490, 205), 135.0, -1.18, 1.18, 72, RED, 18.0, true)
	_draw_arrow(Vector2(365, 205), Vector2(275, 205), Color.WHITE)


func _draw_safe_gap() -> void:
	var center := Vector2(330, 205)
	draw_arc(center, 145.0, -2.55, 2.55, 112, RED, 18.0, true)
	draw_arc(center, 95.0, -2.55, 2.55, 96, BLUE, 14.0, true)
	draw_arc(center, 145.0, -0.28, 0.28, 24, SAFE, 24.0, true)
	_draw_player(Vector2(500, 205))
	_draw_arrow(Vector2(455, 205), Vector2(398, 205), Color.WHITE)


func _draw_resonator() -> void:
	_draw_prompt(KEY_E, Rect2(42, 120, 64, 64))
	_draw_prompt(MOUSE_RIGHT, Rect2(42, 220, 64, 64))
	_draw_resonator_sprite(Vector2(265, 205))
	draw_arc(Vector2(265, 205), 145.0, -1.05, 1.05, 64, VIOLET, 14.0, true)
	_draw_arrow(Vector2(120, 152), Vector2(212, 190), Color.WHITE)
	_draw_arrow(Vector2(120, 252), Vector2(360, 205), VIOLET)


func _draw_blue_violet() -> void:
	var left := Vector2(235, 225)
	var right := Vector2(465, 225)
	draw_arc(left, 155.0, -1.0, 1.0, 64, BLUE, 14.0, true)
	draw_arc(right, 155.0, PI - 1.0, PI + 1.0, 64, VIOLET, 14.0, true)
	_draw_resonator_sprite(right)
	_draw_resonance_node(Vector2(350, 225), BLUE.lerp(VIOLET, 0.5))
	_draw_prompt(KEY_E, Rect2(44, 120, 56, 56))
	_draw_prompt(MOUSE_RIGHT, Rect2(44, 215, 56, 56))


func _draw_violet_pair() -> void:
	var left := Vector2(245, 225)
	var right := Vector2(475, 225)
	_draw_resonator_sprite(left)
	_draw_resonator_sprite(right)
	draw_arc(left, 155.0, -1.0, 1.0, 64, VIOLET, 14.0, true)
	draw_arc(right, 155.0, PI - 1.0, PI + 1.0, 64, VIOLET, 14.0, true)
	_draw_resonance_node(Vector2(360, 225), VIOLET)
	_draw_prompt(MOUSE_RIGHT, Rect2(50, 185, 64, 64))


func _draw_crossbar() -> void:
	_draw_prompt(MOUSE_LEFT, Rect2(45, 145, 66, 66))
	draw_texture_rect(CROSSBAR_TEXTURE, Rect2(268, 147, 46, 116), false)
	draw_arc(Vector2(360, 205), 150.0, -0.62, 0.62, 48, RED, 18.0, true)
	draw_arc(Vector2(360, 205), 150.0, -0.18, 0.18, 20, SAFE, 24.0, true)
	_draw_player(Vector2(545, 205))
	_draw_arrow(Vector2(125, 178), Vector2(262, 190), Color.WHITE)


func _draw_player(center: Vector2) -> void:
	draw_texture_rect_region(
		PLAYER_TEXTURE,
		Rect2(center - Vector2(52, 52), Vector2(104, 104)),
		Rect2(0, 0, 256, 256)
	)


func _draw_resonator_sprite(center: Vector2) -> void:
	draw_texture_rect(RESONATOR_TEXTURE, Rect2(center - Vector2(34, 34), Vector2(68, 68)), false)


func _draw_prompt(texture: Texture2D, rect: Rect2) -> void:
	draw_texture_rect(texture, rect, false)


func _draw_resonance_node(center: Vector2, color: Color) -> void:
	draw_circle(center, 31.0, Color(color.r, color.g, color.b, 0.22))
	draw_circle(center, 17.0, Color(color.r, color.g, color.b, 0.72))
	draw_circle(center, 5.0, Color.WHITE)
	draw_line(center + Vector2(-25, 0), center + Vector2(25, 0), Color.WHITE, 2.0, true)
	draw_line(center + Vector2(0, -25), center + Vector2(0, 25), Color.WHITE, 2.0, true)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 3.0, true)
	var direction := (to - from).normalized()
	var tangent := Vector2(-direction.y, direction.x)
	draw_colored_polygon(
		PackedVector2Array([
			to,
			to - direction * 17.0 + tangent * 8.0,
			to - direction * 17.0 - tangent * 8.0,
		]),
		color
	)
