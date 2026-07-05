class_name WaveEmitter
extends Node2D

@export var wave_kind := "red"
@export var interval := 2.4
@export var initial_delay := 0.5
@export var active_at := 0.0

const TELEGRAPH_TIME := 0.55

var wave_manager
var combat_time := 0.0
var combat_running := false
var _cooldown := 0.0
var _was_active := false


func _ready() -> void:
	_cooldown = initial_delay


func _process(delta: float) -> void:
	var active := combat_running and combat_time >= active_at
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


func _fire_wave() -> void:
	if not is_instance_valid(wave_manager):
		return
	wave_manager.spawn_wave("enemy", wave_kind, global_position)


func _draw() -> void:
	var active := combat_running and combat_time >= active_at
	var base_color := Color(1.0, 0.08, 0.14) if wave_kind == "red" else Color(1.0, 0.78, 0.36)
	var alpha := 1.0 if active else 0.16
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
	draw_line(Vector2(-15, 18), Vector2(15, 18), Color(0.28, 0.26, 0.34, 0.95), 6.0, true)
