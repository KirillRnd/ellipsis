class_name AbilitySlot
extends Control

const FILL_RECT := Rect2(8.0, 8.0, 76.0, 76.0)

var _prompt: Texture2D
var _item: Texture2D
var _kind := ""
var _caption := ""
var _counter := ""
var _readiness := 0.0
var _enabled := false


func _ready() -> void:
	custom_minimum_size = Vector2(92.0, 108.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(prompt: Texture2D, item: Texture2D, kind: String, caption: String) -> void:
	_prompt = prompt
	_item = item
	_kind = kind
	_caption = caption
	queue_redraw()


func set_state(readiness: float, enabled: bool, counter: String = "") -> void:
	_readiness = clampf(readiness, 0.0, 1.0)
	_enabled = enabled
	_counter = counter
	queue_redraw()


func set_caption(caption: String) -> void:
	if _caption == caption:
		return
	_caption = caption
	queue_redraw()


func _draw() -> void:
	draw_rect(FILL_RECT, Color(0.025, 0.030, 0.040, 0.94), true)
	if _readiness > 0.001:
		draw_colored_polygon(_clockwise_fill_polygon(_readiness), _fill_color())
	var border_color := Color(0.78, 0.82, 0.86, 0.95) if _enabled else Color(0.34, 0.36, 0.39, 0.9)
	draw_rect(FILL_RECT, border_color, false, 2.0)

	if _kind == "wave":
		_draw_wave_fragment()
	elif is_instance_valid(_item):
		var item_rect := _contain_texture_rect(_item, Rect2(22.0, 18.0, 56.0, 62.0))
		draw_texture_rect(_item, item_rect, false, Color(1.0, 1.0, 1.0, 0.95 if _enabled else 0.34))

	if is_instance_valid(_prompt):
		draw_texture_rect(_prompt, Rect2(2.0, 1.0, 30.0, 30.0), false)
	if not _counter.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(66.0, 24.0),
			_counter,
			HORIZONTAL_ALIGNMENT_CENTER,
			22.0,
			15,
			Color.WHITE if _enabled else Color(0.55, 0.55, 0.58)
		)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(6.0, 103.0),
		_caption,
		HORIZONTAL_ALIGNMENT_CENTER,
		80.0,
		13,
		Color(0.90, 0.92, 0.94) if _enabled else Color(0.45, 0.46, 0.49)
	)


func _clockwise_fill_polygon(progress: float) -> PackedVector2Array:
	var center := FILL_RECT.get_center()
	var points := PackedVector2Array([center, Vector2(center.x, FILL_RECT.position.y)])
	var end_angle := -PI * 0.5 + TAU * progress
	var corner_angles := [-PI * 0.25, PI * 0.25, PI * 0.75, PI * 1.25]
	for angle in corner_angles:
		if angle < end_angle - 0.0001:
			points.append(_ray_to_square(center, Vector2.from_angle(angle)))
	points.append(_ray_to_square(center, Vector2.from_angle(end_angle)))
	return points


func _ray_to_square(center: Vector2, direction: Vector2) -> Vector2:
	var half_size := FILL_RECT.size * 0.5
	var x_scale := INF if absf(direction.x) < 0.0001 else half_size.x / absf(direction.x)
	var y_scale := INF if absf(direction.y) < 0.0001 else half_size.y / absf(direction.y)
	return center + direction * minf(x_scale, y_scale)


func _fill_color() -> Color:
	if not _enabled:
		return Color(0.14, 0.15, 0.17, 0.72)
	if _kind == "wave":
		return Color(0.35, 0.10, 0.58, 0.86)
	if _kind == "resonator":
		return Color(0.25, 0.12, 0.43, 0.86)
	return Color(0.30, 0.32, 0.35, 0.92)


func _contain_texture_rect(texture: Texture2D, bounds: Rect2) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return bounds
	var scale_factor := minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	return Rect2(bounds.get_center() - draw_size * 0.5, draw_size)


func _draw_wave_fragment() -> void:
	var color := Color(0.77, 0.30, 1.0, 0.96) if _enabled else Color(0.38, 0.30, 0.42, 0.7)
	draw_arc(Vector2(49.0, 51.0), 24.0, -2.35, 0.45, 26, color, 7.0, true)
	draw_arc(Vector2(49.0, 51.0), 15.0, -2.35, 0.45, 20, color.lightened(0.18), 3.0, true)
