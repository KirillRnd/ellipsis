class_name TutorialDiagram
extends Control

const PLAYER_TEXTURE := preload("res://assets/actors/colorless/colorless_idle_sheet.png")
const RESONATOR_TEXTURE := preload("res://assets/actors/resonator_crystal_base.png")
const CROSSBAR_TEXTURE := preload("res://assets/items/kovyryalka_driven.png")
const KEY_W := preload("res://assets/ui/input_prompts/keyboard_w.png")
const KEY_A := preload("res://assets/ui/input_prompts/keyboard_a.png")
const KEY_S := preload("res://assets/ui/input_prompts/keyboard_s.png")
const KEY_D := preload("res://assets/ui/input_prompts/keyboard_d.png")
const KEY_SPACE := preload("res://assets/ui/input_prompts/keyboard_space.png")
const KEY_E := preload("res://assets/ui/input_prompts/keyboard_e.png")
const MOUSE_LEFT := preload("res://assets/ui/input_prompts/mouse_left.png")
const MOUSE_RIGHT := preload("res://assets/ui/input_prompts/mouse_right.png")

const RED := Color(1.0, 0.06, 0.13)
const BLUE := Color(0.24, 0.72, 1.0)
const VIOLET := Color(0.44, 0.19, 1.0)
const SAFE := Color(0.91, 0.90, 0.87, 0.88)
const CROSSBAR_GREY := Color(0.56, 0.57, 0.58)
const CREST_WIDTH := 14.0
const SAFE_GAP_CLEAR_WIDTH := 32.0
const SAFE_GAP_CORE_WIDTH := 13.333333
const SAFE_GAP_JAMB_DEPTH := 28.0

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
	_draw_prompt(KEY_SPACE, Rect2(105, 235, 54, 54))
	_draw_wave_arc(Vector2(490, 205), 135.0, -1.18, 1.18, RED)
	_draw_arrow(Vector2(365, 205), Vector2(275, 205), Color.WHITE)


func _draw_safe_gap() -> void:
	var red_center := Vector2(285, 180)
	var blue_center := Vector2(485, 180)
	var red_radius := 150.0
	var blue_radius := 120.0
	_draw_wave_arc(red_center, red_radius, -2.45, 2.45, RED)
	_draw_wave_arc(blue_center, blue_radius, PI - 2.2, PI + 2.2, BLUE)
	var intersections := _circle_intersections(red_center, red_radius, blue_center, blue_radius)
	for point in intersections:
		var red_angle: float = (point - red_center).angle()
		var blue_angle: float = (point - blue_center).angle()
		_draw_safe_gap_arc(red_center, red_radius, red_angle - 0.30, red_angle + 0.30, RED, BLUE)
		_draw_safe_gap_arc(blue_center, blue_radius, blue_angle - 0.30, blue_angle + 0.30, BLUE, RED)
	_draw_player(Vector2(545, 74))
	_draw_arrow(Vector2(512, 96), intersections[0] if not intersections.is_empty() else Vector2(420, 105), Color.WHITE)


func _draw_resonator() -> void:
	_draw_prompt(KEY_E, Rect2(42, 120, 64, 64))
	_draw_prompt(MOUSE_RIGHT, Rect2(42, 220, 64, 64))
	_draw_resonator_sprite(Vector2(265, 205))
	_draw_wave_arc(Vector2(265, 205), 145.0, -1.05, 1.05, VIOLET)
	_draw_arrow(Vector2(120, 152), Vector2(212, 190), Color.WHITE)
	_draw_arrow(Vector2(120, 252), Vector2(360, 205), VIOLET)


func _draw_blue_violet() -> void:
	var left := Vector2(235, 180)
	var right := Vector2(465, 180)
	var radius := 155.0
	_draw_wave_arc(left, radius, -1.0, 1.0, BLUE)
	_draw_wave_arc(right, radius, PI - 1.0, PI + 1.0, VIOLET)
	_draw_resonator_sprite(right)
	for point in _circle_intersections(left, radius, right, radius):
		_draw_resonance_node(point, "blue_violet")
	_draw_prompt(KEY_E, Rect2(44, 120, 56, 56))
	_draw_prompt(MOUSE_RIGHT, Rect2(44, 215, 56, 56))


func _draw_violet_pair() -> void:
	var left := Vector2(245, 180)
	var right := Vector2(475, 180)
	var radius := 155.0
	_draw_resonator_sprite(left)
	_draw_resonator_sprite(right)
	_draw_wave_arc(left, radius, -1.0, 1.0, VIOLET)
	_draw_wave_arc(right, radius, PI - 1.0, PI + 1.0, VIOLET)
	for point in _circle_intersections(left, radius, right, radius):
		_draw_resonance_node(point, "violet_violet")
	_draw_prompt(MOUSE_RIGHT, Rect2(50, 185, 64, 64))


func _draw_crossbar() -> void:
	var short_center := Vector2(175, 205)
	var short_radius := 100.0
	var long_center := Vector2(450, 205)
	var long_radius := 135.0
	_draw_prompt(MOUSE_LEFT, Rect2(45, 52, 60, 60))
	_draw_prompt(MOUSE_LEFT, Rect2(370, 52, 60, 60))
	draw_arc(Vector2(400, 82), 38.0, -PI * 0.5, PI * 1.35, 32, Color.WHITE, 3.0, true)
	_draw_wave_arc(short_center, short_radius, -1.0, 1.0, RED)
	_draw_safe_gap_arc(
		short_center,
		short_radius,
		-SteelCrossbarDriven.MIN_GAP_WIDTH * 0.5 / short_radius,
		SteelCrossbarDriven.MIN_GAP_WIDTH * 0.5 / short_radius,
		RED,
		CROSSBAR_GREY
	)
	_draw_crossbar_sprite(short_center + Vector2(short_radius, 0.0), 72.0)
	_draw_wave_arc(long_center, long_radius, -1.0, 1.0, RED)
	_draw_safe_gap_arc(
		long_center,
		long_radius,
		-SteelCrossbarDriven.MAX_GAP_WIDTH * 0.5 / long_radius,
		SteelCrossbarDriven.MAX_GAP_WIDTH * 0.5 / long_radius,
		RED,
		CROSSBAR_GREY
	)
	_draw_crossbar_sprite(long_center + Vector2(long_radius, 0.0), 72.0)


func _draw_player(center: Vector2) -> void:
	draw_texture_rect_region(
		PLAYER_TEXTURE,
		Rect2(center - Vector2(52, 52), Vector2(104, 104)),
		Rect2(0, 0, 256, 256)
	)


func _draw_resonator_sprite(center: Vector2) -> void:
	var source_size := RESONATOR_TEXTURE.get_size()
	var draw_height := 68.0
	var draw_width := draw_height * source_size.x / source_size.y
	var draw_size := Vector2(draw_width, draw_height)
	draw_texture_rect(RESONATOR_TEXTURE, Rect2(center - draw_size * 0.5, draw_size), false)


func _draw_crossbar_sprite(center: Vector2, height: float) -> void:
	var source_size := CROSSBAR_TEXTURE.get_size()
	var draw_size := Vector2(height * source_size.x / source_size.y, height)
	draw_texture_rect(CROSSBAR_TEXTURE, Rect2(center - draw_size * 0.5, draw_size), false)


func _draw_prompt(texture: Texture2D, rect: Rect2) -> void:
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor := minf(rect.size.x / source_size.x, rect.size.y / source_size.y)
	var draw_size := source_size * scale_factor
	draw_texture_rect(texture, Rect2(rect.get_center() - draw_size * 0.5, draw_size), false)


func _circle_intersections(
	first_center: Vector2,
	first_radius: float,
	second_center: Vector2,
	second_radius: float
) -> Array[Vector2]:
	var delta := second_center - first_center
	var distance := delta.length()
	if (
		distance <= 0.0001
		or distance > first_radius + second_radius
		or distance < absf(first_radius - second_radius)
	):
		return []
	var along := (
		first_radius * first_radius
		- second_radius * second_radius
		+ distance * distance
	) / (2.0 * distance)
	var height := sqrt(maxf(0.0, first_radius * first_radius - along * along))
	var direction := delta / distance
	var midpoint := first_center + direction * along
	var perpendicular := Vector2(-direction.y, direction.x)
	return [
		midpoint - perpendicular * height,
		midpoint + perpendicular * height,
	]


func _draw_wave_arc(
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	color: Color
) -> void:
	var point_count := maxi(8, int(ceil(absf(end_angle - start_angle) / TAU * 160.0)))
	var glow_color := color
	glow_color.a = 0.10
	var line_color := color
	line_color.a = 0.78
	var core_color := color.lerp(Color.WHITE, 0.68)
	core_color.a = 0.42
	draw_arc(center, radius, start_angle, end_angle, point_count, glow_color, CREST_WIDTH * 2.0, true)
	draw_arc(center, radius, start_angle, end_angle, point_count, line_color, CREST_WIDTH * 0.85, true)
	draw_arc(center, radius, start_angle, end_angle, point_count, core_color, 2.0, true)


func _draw_safe_gap_arc(
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	protected_color: Color,
	inner_color: Color
) -> void:
	var point_count := maxi(8, int(ceil(absf(end_angle - start_angle) / TAU * 160.0)))
	var calm := inner_color
	calm.a = 0.10
	draw_arc(center, radius, start_angle, end_angle, point_count, SAFE, SAFE_GAP_CLEAR_WIDTH, true)
	draw_arc(center, radius, start_angle, end_angle, point_count, calm, SAFE_GAP_CORE_WIDTH, true)
	_draw_safe_gap_jamb(center, radius, start_angle, 1.0, protected_color, inner_color)
	_draw_safe_gap_jamb(center, radius, end_angle, -1.0, protected_color, inner_color)


func _draw_safe_gap_jamb(
	center: Vector2,
	radius: float,
	edge_angle: float,
	inner_sign: float,
	protected_color: Color,
	inner_color: Color
) -> void:
	var direction := Vector2.from_angle(edge_angle)
	var tangent := Vector2(-direction.y, direction.x)
	var jamb_center := center + direction * radius
	var from := jamb_center - direction * SAFE_GAP_JAMB_DEPTH
	var to := jamb_center + direction * SAFE_GAP_JAMB_DEPTH
	var normal := (tangent * inner_sign).normalized()
	_draw_safe_gap_boundary_half(from, to, -normal, protected_color)
	_draw_safe_gap_boundary_half(from, to, normal, inner_color)


func _draw_safe_gap_boundary_half(
	from: Vector2,
	to: Vector2,
	side: Vector2,
	base_color: Color
) -> void:
	var glow_color := base_color
	glow_color.a = 0.10
	var line_color := base_color
	line_color.a = 0.78
	var core_color := base_color.lerp(Color.WHITE, 0.68)
	core_color.a = 0.42
	_draw_offset_line(from, to, side, glow_color, CREST_WIDTH)
	_draw_offset_line(from, to, side, line_color, CREST_WIDTH * 0.425)
	_draw_offset_line(from, to, side, core_color, 1.0)


func _draw_offset_line(
	from: Vector2,
	to: Vector2,
	side: Vector2,
	color: Color,
	width: float
) -> void:
	var offset := side * width * 0.5
	draw_line(from + offset, to + offset, color, width, true)


func _draw_resonance_node(center: Vector2, resonance_type: String) -> void:
	var outer := Color(0.10, 0.45, 1.0, 0.22)
	var middle := Color(0.24, 0.72, 1.0, 0.58)
	var line := Color(0.72, 0.94, 1.0, 0.72)
	if resonance_type == "violet_violet":
		outer = Color(0.52, 0.12, 0.86, 0.26)
		middle = Color(0.78, 0.26, 1.0, 0.66)
		line = Color(0.92, 0.68, 1.0, 0.80)
	draw_circle(center, 28.0, outer)
	draw_circle(center, 14.0, middle)
	draw_circle(center, 5.0, Color(0.96, 0.94, 1.0, 0.96))
	draw_line(center + Vector2(-16, 0), center + Vector2(16, 0), line, 2.0, true)
	draw_line(center + Vector2(0, -16), center + Vector2(0, 16), line, 2.0, true)


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
