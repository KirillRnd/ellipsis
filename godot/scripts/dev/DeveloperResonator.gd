class_name DeveloperResonator
extends Node2D

var color_index := 0
var sequence_id := 0
var front_angle := 0.0
var pulse := 0.0


func configure(new_color_index: int, new_sequence_id: int, new_front_angle: float) -> void:
	color_index = new_color_index
	sequence_id = new_sequence_id
	front_angle = new_front_angle
	queue_redraw()


func trigger() -> void:
	pulse = 1.0


func _process(delta: float) -> void:
	pulse = maxf(0.0, pulse - delta * 3.5)
	queue_redraw()


func _draw() -> void:
	var spec := ResonanceCatalog.color_spec(color_index)
	var color: Color = spec["color"]
	var radius := 19.0 + pulse * 5.0
	draw_circle(Vector2.ZERO, radius + 7.0, Color(color, 0.10))
	draw_circle(Vector2.ZERO, radius, Color(0.018, 0.022, 0.030, 0.98))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color.lightened(0.25), 3.0, true)
	draw_circle(Vector2.ZERO, 7.0, color)
	draw_string(ThemeDB.fallback_font, Vector2(-12.0, 6.0), spec["symbol"], HORIZONTAL_ALIGNMENT_CENTER, 24.0, 17, Color.WHITE)
	if spec["geometry"] == "line":
		var tangent := Vector2.from_angle(front_angle + PI * 0.5)
		draw_line(-tangent * 28.0, tangent * 28.0, Color(color, 0.72), 2.0, true)
