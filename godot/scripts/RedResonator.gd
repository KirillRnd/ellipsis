class_name RedResonator
extends Node2D


const TEXTURE := preload("res://assets/actors/resonator_red_base.png")
const VISUAL_SIZE := Vector2(64.0, 64.0)

var pulse := 0.0


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func trigger() -> void:
	pulse = 0.0
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, Wave.PLAYER_MAX_RADIUS, Color(0.55, 0.03, 0.08, 0.025))
	draw_arc(
		Vector2.ZERO,
		Wave.PLAYER_MAX_RADIUS,
		0.0,
		TAU,
		192,
		Color(0.88, 0.08, 0.14, 0.18),
		2.0,
		true
	)
	draw_texture_rect(
		TEXTURE,
		Rect2(-VISUAL_SIZE * 0.5, VISUAL_SIZE),
		false,
		Color.WHITE
	)
	var pulse_radius := 7.0 + exp(-pulse * 6.0) * 8.0
	draw_arc(
		Vector2.ZERO,
		pulse_radius,
		0.0,
		TAU,
		48,
		Color(1.0, 0.28, 0.32, 0.90),
		2.0,
		true
	)
