class_name BlueBeacon
extends Node2D

signal fired_friendly_wave(origin: Vector2)

@export var interval := 3.2
@export var initial_delay := 0.45
@export var active_at := 0.0

const BLUE_REACH_RADIUS := Wave.RED_MAX_RADIUS
const TELEGRAPH_TIME := 0.65
const TIMER_BAR_HEIGHT := 7.0
const BEACON_TEXTURE := preload("res://assets/actors/beacon_blue_base.png")

var combat_time := 0.0
var combat_running := false
var _cooldown := 0.0
var _was_active := false


func _ready() -> void:
	_cooldown = initial_delay


func _process(delta: float) -> void:
	var active := _is_active()
	if active and not _was_active:
		_cooldown = initial_delay
	_was_active = active

	if not active:
		queue_redraw()
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		fired_friendly_wave.emit(global_position)
		_cooldown += interval
	queue_redraw()


func _is_active() -> bool:
	return combat_running and combat_time >= active_at


func _draw() -> void:
	var active := _is_active()
	var base := Color(0.20, 0.70, 1.0)
	var alpha := 1.0 if active else 0.22
	var charge := 0.0
	if active and _cooldown <= TELEGRAPH_TIME:
		charge = 1.0 - clampf(_cooldown / TELEGRAPH_TIME, 0.0, 1.0)

	var fill := base
	fill.a = 0.030 if active else 0.014
	var edge := base
	edge.a = 0.20 if active else 0.08
	draw_circle(Vector2.ZERO, BLUE_REACH_RADIUS, fill)
	draw_arc(Vector2.ZERO, BLUE_REACH_RADIUS, 0.0, TAU, 192, edge, 2.0, true)

	var size := Vector2(72, 72)
	draw_texture_rect(BEACON_TEXTURE, Rect2(-size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))
	_draw_hitbox(base, alpha)
	_draw_wave_timer(base, active, charge)


func _draw_hitbox(base_color: Color, alpha: float) -> void:
	var visibility := maxf(alpha, 0.42)
	var fill := base_color.lerp(Color.WHITE, 0.35)
	fill.a = 0.72 * visibility
	var edge := base_color.lerp(Color.WHITE, 0.20)
	edge.a = 0.95 * visibility
	draw_circle(Vector2.ZERO, 5.0, fill)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 48, edge, 2.0, true)


func _draw_wave_timer(base_color: Color, active: bool, charge: float) -> void:
	var width := 86.0
	var pos := Vector2(-width * 0.5, -55.0)
	var bg := Rect2(pos, Vector2(width, TIMER_BAR_HEIGHT))
	draw_rect(bg, Color(0.02, 0.015, 0.025, 0.88))

	if active and interval > 0.0:
		var ready := 1.0 - clampf(_cooldown / interval, 0.0, 1.0)
		var fill := base_color.lerp(Color.WHITE, 0.45 * charge)
		fill.a = 0.88
		draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2((width - 2.0) * ready, TIMER_BAR_HEIGHT - 2.0)), fill)

	for tick in range(1, 4):
		var x := pos.x + width * float(tick) / 4.0
		draw_line(Vector2(x, pos.y + 1.0), Vector2(x, pos.y + TIMER_BAR_HEIGHT - 1.0), Color(0.92, 0.88, 0.82, 0.24), 1.0, false)
	draw_rect(bg, Color(0.78, 0.93, 1.0, 0.55 if active else 0.22), false, 1.0)
