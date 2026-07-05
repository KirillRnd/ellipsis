class_name WaveEmitter
extends Node2D

signal defeated(emitter)

@export var wave_kind := "red"
@export var interval := 2.4
@export var initial_delay := 0.5
@export var active_at := 0.0
@export var max_hit_points := 8

const TELEGRAPH_TIME := 0.55

var wave_manager
var combat_time := 0.0
var combat_running := false
var hit_points := 8
var _cooldown := 0.0
var _was_active := false
var _hit_flash := 0.0


func _ready() -> void:
	hit_points = max_hit_points
	_cooldown = initial_delay


func _process(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var active := _is_active()
	if active and not _was_active:
		_cooldown = initial_delay
	_was_active = active

	if not active:
		queue_redraw()
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		_fire_wave()
		_cooldown += interval
	queue_redraw()


func _is_active() -> bool:
	return combat_running and combat_time >= active_at and not is_destroyed()


func is_destroyed() -> bool:
	return hit_points <= 0


func can_take_damage() -> bool:
	return _is_active()


func take_damage(amount: int) -> void:
	if is_destroyed():
		return
	hit_points = maxi(0, hit_points - amount)
	_hit_flash = 0.16
	if hit_points <= 0:
		_cooldown = initial_delay
		_was_active = false
		defeated.emit(self)
	queue_redraw()


func _fire_wave() -> void:
	if not is_instance_valid(wave_manager):
		return
	wave_manager.spawn_wave("enemy", wave_kind, global_position)


func _draw() -> void:
	var active := _is_active()
	var base_color := Color(1.0, 0.08, 0.14) if wave_kind == "red" else Color(1.0, 0.78, 0.36)
	var alpha := 1.0 if active else 0.16
	if is_destroyed():
		alpha = 0.06
	var charge := 0.0
	if active and _cooldown <= TELEGRAPH_TIME:
		charge = 1.0 - clampf(_cooldown / TELEGRAPH_TIME, 0.0, 1.0)

	var body := Color(0.040, 0.035, 0.050, 1.0)
	var rim := Color(0.24, 0.22, 0.30, 0.80 * alpha)
	var core := base_color
	core.a = alpha
	var glow := base_color
	glow.a = (0.16 + charge * 0.22) * alpha
	var charge_color := base_color
	charge_color.a = charge * 0.85

	draw_circle(Vector2.ZERO, 42.0 + charge * 13.0, glow)
	draw_circle(Vector2.ZERO, 25.0, body)
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 72, rim, 5.0, true)
	draw_circle(Vector2.ZERO, 11.0 + charge * 3.0, core)
	if active:
		draw_arc(Vector2.ZERO, 34.0 + charge * 16.0, 0.0, TAU, 96, charge_color, 4.0 + charge * 3.0, true)
		draw_arc(Vector2.ZERO, 17.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(1.0, 0.86, 0.86, 0.8 * charge), 3.0, true)
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, 31.0, Color(0.80, 0.92, 1.0, 0.55))
	draw_line(Vector2(-15, 18), Vector2(15, 18), Color(0.28, 0.26, 0.34, 0.95), 6.0, true)
	_draw_hp_bar()


func _draw_hp_bar() -> void:
	var width := 54.0
	var ratio := 0.0 if max_hit_points <= 0 else float(hit_points) / float(max_hit_points)
	var bg := Rect2(Vector2(-width * 0.5, -42.0), Vector2(width, 5.0))
	draw_rect(bg, Color(0.02, 0.015, 0.025, 0.85))
	draw_rect(Rect2(bg.position, Vector2(width * ratio, 5.0)), Color(0.26, 0.78, 1.0, 0.90))
	draw_rect(bg, Color(0.82, 0.92, 1.0, 0.55), false, 1.0)
