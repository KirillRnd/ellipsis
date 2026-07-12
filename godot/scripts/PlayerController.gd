class_name PlayerController
extends CharacterBody2D

signal fired_counter_wave(origin: Vector2)
signal hit_points_changed(hit_points: int)
signal died

const ARENA_RECT := Rect2(Vector2(110, 90), Vector2(1060, 560))
const SPEED := 245.0
const DASH_SPEED := 650.0
const DASH_TIME := 0.13
const DASH_COOLDOWN := 0.55
const INVULNERABLE_TIME := 1.05
const FIRE_COOLDOWN := 0.11
const HELD_FIRE_INTERVAL := 0.22
const COUNTER_WAVE_REACH_RADIUS := Wave.PLAYER_MAX_RADIUS
const PLAYER_TEXTURE := preload("res://assets/actors/player_bescolor_topdown.png")

var hit_points := 30
var counter_wave_enabled := false
var _fire_cooldown := 0.0
var _held_fire_timer := 0.0
var _dash_time_left := 0.0
var _dash_cooldown := 0.0
var _invulnerable_left := 0.0
var _last_move_dir := Vector2.UP
var _fire_was_down := false
var _dash_was_down := false


func _ready() -> void:
	hit_points_changed.emit(hit_points)


func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_dash_time_left = maxf(0.0, _dash_time_left - delta)

	var input_dir := _read_move_input()
	if input_dir.length_squared() > 0.0:
		_last_move_dir = input_dir

	var dash_down := Input.is_key_pressed(KEY_SPACE)
	if dash_down and not _dash_was_down and _dash_cooldown <= 0.0:
		_dash_time_left = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
	_dash_was_down = dash_down

	var move_speed := DASH_SPEED if _dash_time_left > 0.0 else SPEED
	velocity = _last_move_dir * move_speed if _dash_time_left > 0.0 else input_dir * move_speed
	move_and_slide()
	global_position = global_position.clamp(ARENA_RECT.position, ARENA_RECT.end)

	_update_counter_wave_input(delta)
	queue_redraw()


func _read_move_input() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir.normalized()


func _update_counter_wave_input(delta: float) -> void:
	var fire_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if fire_down and not _fire_was_down:
		_try_fire_counter_wave()
		_held_fire_timer = HELD_FIRE_INTERVAL
	elif fire_down:
		_held_fire_timer -= delta
		while _held_fire_timer <= 0.0:
			_try_fire_counter_wave()
			_held_fire_timer += HELD_FIRE_INTERVAL
	else:
		_held_fire_timer = 0.0
	_fire_was_down = fire_down


func _try_fire_counter_wave() -> void:
	if not counter_wave_enabled:
		return
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = FIRE_COOLDOWN
	fired_counter_wave.emit(global_position)


func take_hit(amount: int = 1) -> void:
	if is_invulnerable():
		return
	hit_points -= amount
	_invulnerable_left = INVULNERABLE_TIME
	hit_points_changed.emit(hit_points)
	if hit_points <= 0:
		died.emit()


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func get_cooldown_ratio() -> float:
	if FIRE_COOLDOWN <= 0.0:
		return 0.0
	return clampf(_fire_cooldown / FIRE_COOLDOWN, 0.0, 1.0)


func _draw() -> void:
	var blink := is_invulnerable() and int(Time.get_ticks_msec() / 80) % 2 == 0
	var body_color := Color(0.45, 0.22, 1.0, 0.45 if blink else 1.0)
	var core_color := Color(0.85, 0.78, 1.0, 0.75 if blink else 1.0)
	var hitbox_color := Color(0.30, 0.85, 1.0, 0.95)
	var sprite_alpha := 0.45 if blink else 1.0

	_draw_counter_wave_reach()
	draw_circle(Vector2.ZERO, 30.0, Color(0.0, 0.0, 0.0, 0.72))
	draw_circle(Vector2.ZERO, 22.0, Color(0.25, 0.08, 1.0, 0.30))
	draw_texture_rect(PLAYER_TEXTURE, Rect2(Vector2(-34, -34), Vector2(68, 68)), false, Color(1.0, 1.0, 1.0, sprite_alpha))
	draw_circle(Vector2.ZERO, 11.0, body_color)
	draw_circle(Vector2(0, -3), 5.0, core_color)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 48, hitbox_color, 2.0, true)
	draw_line(Vector2.ZERO, _last_move_dir * 22.0, Color(0.90, 0.82, 1.0, 0.95), 2.0, true)


func _draw_counter_wave_reach() -> void:
	draw_circle(Vector2.ZERO, COUNTER_WAVE_REACH_RADIUS, Color(0.44, 0.19, 1.0, 0.035))
	draw_arc(Vector2.ZERO, COUNTER_WAVE_REACH_RADIUS, 0.0, TAU, 192, Color(0.58, 0.34, 1.0, 0.24), 2.0, true)



