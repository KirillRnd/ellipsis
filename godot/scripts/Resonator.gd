class_name Resonator
extends Node2D

signal expired(resonator)

@export var lifetime := 8.0

const DAMAGE_RADIUS := Wave.PLAYER_MAX_RADIUS
const RESONATOR_TEXTURE := preload("res://assets/actors/resonator_crystal_base.png")

var age := 0.0
var pulse := 0.0


func _process(delta: float) -> void:
	age += delta
	pulse += delta
	if age >= lifetime:
		expired.emit(self)
		queue_free()
		return
	queue_redraw()


func trigger() -> void:
	age = maxf(age - 0.35, 0.0)
	pulse = 0.0
	queue_redraw()


func _draw() -> void:
	var remaining := clampf(1.0 - age / lifetime, 0.0, 1.0)
	var alpha := 0.35 + 0.65 * remaining
	_draw_damage_reach(alpha)

	var size := Vector2(58, 58)
	draw_texture_rect(RESONATOR_TEXTURE, Rect2(-size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))

	var hitbox_color := Color(0.78, 0.58, 1.0, 0.95 * alpha)
	draw_circle(Vector2.ZERO, 5.0, Color(0.50, 0.25, 1.0, 0.75 * alpha))
	draw_arc(Vector2.ZERO, 7.0 + sin(pulse * 8.0) * 0.8, 0.0, TAU, 48, hitbox_color, 2.0, true)

	var width := 48.0
	var bg := Rect2(Vector2(-width * 0.5, -39.0), Vector2(width, 4.0))
	draw_rect(bg, Color(0.02, 0.015, 0.025, 0.78 * alpha))
	draw_rect(Rect2(bg.position, Vector2(width * remaining, 4.0)), Color(0.62, 0.40, 1.0, 0.82 * alpha))
	draw_rect(bg, Color(0.88, 0.78, 1.0, 0.48 * alpha), false, 1.0)


func _draw_damage_reach(alpha: float) -> void:
	draw_circle(Vector2.ZERO, DAMAGE_RADIUS, Color(0.44, 0.19, 1.0, 0.035 * alpha))
	draw_arc(Vector2.ZERO, DAMAGE_RADIUS, 0.0, TAU, 192, Color(0.64, 0.42, 1.0, 0.24 * alpha), 2.0, true)
