class_name PlayerController
extends CharacterBody2D

signal fired_counter_wave(origin: Vector2)
signal hit_points_changed(hit_points: int)
signal died

const ARENA_RECT := Rect2(Vector2(110, 90), Vector2(1060, 560))
const SPEED := 318.5
const DASH_SPEED := 650.0
const DASH_TIME := 0.13
const DASH_COOLDOWN := 0.55
const INVULNERABLE_TIME := 1.05
const FIRE_COOLDOWN := 0.11
const HELD_FIRE_INTERVAL := 0.22
const COUNTER_WAVE_REACH_RADIUS := Wave.PLAYER_MAX_RADIUS
const DASH_VISUAL_OFFSET := Vector2(0.0, -128.0)

@onready var _visual_root: Node2D = $VisualRoot
@onready var _body: AnimatedSprite2D = $VisualRoot/Body

var hit_points := 30
var counter_wave_enabled := false
var dash_enabled := true
var _fire_cooldown := 0.0
var _held_fire_timer := 0.0
var _dash_time_left := 0.0
var _dash_cooldown := 0.0
var _invulnerable_left := 0.0
var _last_move_dir := Vector2.UP
var _fire_was_down := false
var _dash_was_down := false
var _base_animation := &"idle"
var _action_animation := &""


func _ready() -> void:
	_body.animation_finished.connect(_on_body_animation_finished)
	_body.play(&"idle")
	hit_points_changed.emit(hit_points)


func reset_for_encounter(start_position: Vector2, restore_hit_points: bool = true) -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	_fire_cooldown = 0.0
	_held_fire_timer = 0.0
	_dash_time_left = 0.0
	_dash_cooldown = 0.0
	_invulnerable_left = 0.0
	_fire_was_down = false
	_dash_was_down = false
	_action_animation = &""
	_base_animation = &"idle"
	if is_instance_valid(_body):
		_body.offset = Vector2.ZERO
		_body.play(&"idle")
	if restore_hit_points:
		hit_points = 30
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
	if dash_enabled and dash_down and not _dash_was_down and _dash_cooldown <= 0.0:
		_dash_time_left = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		play_action(&"dash")
	_dash_was_down = dash_down

	var move_speed := DASH_SPEED if _dash_time_left > 0.0 else SPEED
	velocity = _last_move_dir * move_speed if _dash_time_left > 0.0 else input_dir * move_speed
	move_and_slide()
	global_position = global_position.clamp(ARENA_RECT.position, ARENA_RECT.end)

	_update_visual_state(input_dir)
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
	play_action(&"hit")
	hit_points_changed.emit(hit_points)
	if hit_points <= 0:
		died.emit()


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func get_cooldown_ratio() -> float:
	if FIRE_COOLDOWN <= 0.0:
		return 0.0
	return clampf(_fire_cooldown / FIRE_COOLDOWN, 0.0, 1.0)


func play_action(animation_name: StringName, facing_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_body):
		return
	if not _body.sprite_frames.has_animation(animation_name):
		return
	if facing_direction.length_squared() > 0.0:
		_last_move_dir = facing_direction.normalized()
		_update_visual_rotation()
	_action_animation = animation_name
	_body.offset = DASH_VISUAL_OFFSET if animation_name == &"dash" else Vector2.ZERO
	_body.play(animation_name)


func _update_visual_state(input_dir: Vector2) -> void:
	if not is_instance_valid(_visual_root) or not is_instance_valid(_body):
		return
	_update_visual_rotation()
	var blink := is_invulnerable() and int(Time.get_ticks_msec() / 80) % 2 == 0
	_body.modulate.a = 0.45 if blink else 1.0
	_base_animation = &"move" if input_dir.length_squared() > 0.0 or _dash_time_left > 0.0 else &"idle"
	if _action_animation == &"" and _body.animation != _base_animation:
		_body.play(_base_animation)


func _update_visual_rotation() -> void:
	_visual_root.rotation = _last_move_dir.angle() + PI * 0.5


func _on_body_animation_finished() -> void:
	if _action_animation == &"":
		return
	_action_animation = &""
	_body.offset = Vector2.ZERO
	_body.play(_base_animation)


func _draw() -> void:
	var blink := is_invulnerable() and int(Time.get_ticks_msec() / 80) % 2 == 0
	var center_color := Color(0.45, 0.22, 1.0, 0.55 if blink else 0.85)
	var hitbox_color := Color(0.30, 0.85, 1.0, 0.95)

	_draw_counter_wave_reach()
	draw_circle(Vector2.ZERO, 5.0, center_color)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 48, hitbox_color, 2.0, true)


func _draw_counter_wave_reach() -> void:
	if not counter_wave_enabled:
		return
	draw_circle(Vector2.ZERO, COUNTER_WAVE_REACH_RADIUS, Color(0.44, 0.19, 1.0, 0.035))
	draw_arc(Vector2.ZERO, COUNTER_WAVE_REACH_RADIUS, 0.0, TAU, 192, Color(0.58, 0.34, 1.0, 0.24), 2.0, true)



