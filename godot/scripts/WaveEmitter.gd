class_name WaveEmitter
extends Node2D

@export var wave_kind := "red"
@export var interval := 2.4
@export var initial_delay := 0.5
@export var active_at := 0.0

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
	var alpha := 1.0 if active else 0.25
	var glow := base_color
	glow.a = 0.22 * alpha
	var core := base_color
	core.a = alpha

	draw_circle(Vector2.ZERO, 34.0, glow)
	draw_circle(Vector2.ZERO, 17.0, Color(0.055, 0.045, 0.07, 1.0))
	draw_circle(Vector2.ZERO, 10.0, core)
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 64, core, 3.0, true)
	draw_line(Vector2(-13, 16), Vector2(13, 16), Color(0.26, 0.24, 0.32), 5.0, true)

