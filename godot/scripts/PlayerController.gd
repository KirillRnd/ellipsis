class_name PlayerController
extends CharacterBody2D

signal crossbar_short_committed(origin: Vector2)
signal crossbar_long_committed(origin: Vector2, direction: Vector2)
signal crossbar_action_started(animation_name: StringName)
signal crossbar_drive_impact(origin: Vector2, direction: Vector2, is_oriented: bool)
signal crossbar_aim_cancelled
signal hit_points_changed(hit_points: int)
signal defeat_started
signal died

enum CrossbarInputState {
	READY,
	PRESSING,
	AIMING,
	RECOVERING,
	CANCELLED,
}

const ARENA_RECT := Rect2(Vector2(110, 90), Vector2(1060, 560))
const SPEED := 318.5
const DASH_FRAME_COUNT := 3.0
const DASH_ANIMATION_FPS := 24.0
const DASH_TIME := DASH_FRAME_COUNT / DASH_ANIMATION_FPS
const DASH_DISTANCE := 84.0
const DASH_SPEED := DASH_DISTANCE / DASH_TIME
const DASH_COOLDOWN := 0.55
const INVULNERABLE_TIME := 1.05
const DASH_FRAME_OFFSETS := [
	Vector2(4.0, -43.0),
	Vector2(0.0, -18.0),
	Vector2(0.0, -16.0),
]
const CROSSBAR_HOLD_THRESHOLD := 0.16
const CROSSBAR_AIM_SPEED_FACTOR := 0.55
const CROSSBAR_HOLD_FRAME := 2
const CROSSBAR_IMPACT_FRAME := 3
const DEFEAT_TIME := 0.45

@onready var _visual_root: Node2D = $VisualRoot
@onready var _crossbar_pivot: Node2D = $VisualRoot/CrossbarPivot
@onready var _body: AnimatedSprite2D = $VisualRoot/Body

var hit_points := 30
var crossbar_enabled := true
var dash_enabled := true
var controls_enabled := true
var _dash_time_left := 0.0
var _dash_distance_left := 0.0
var _dash_cooldown := 0.0
var _invulnerable_left := 0.0
var _last_move_dir := Vector2.UP
var _dash_was_down := false
var _base_animation := &"idle"
var _action_animation := &""
var _crossbar_state := CrossbarInputState.READY
var _crossbar_hold_time := 0.0
var _crossbar_was_down := false
var _crossbar_aim_direction := Vector2.UP
var _crossbar_impact_pending := false
var _crossbar_impact_origin := Vector2.ZERO
var _crossbar_impact_direction := Vector2.UP
var _crossbar_impact_is_oriented := false
var _defeated := false
var _defeat_time_left := 0.0
var _death_emitted := false


func _ready() -> void:
	_body.animation_finished.connect(_on_body_animation_finished)
	_body.frame_changed.connect(_on_body_frame_changed)
	_crossbar_pivot.visible = false
	_body.play(&"idle")
	hit_points_changed.emit(hit_points)


func reset_for_encounter(start_position: Vector2, restore_hit_points: bool = true) -> void:
	controls_enabled = true
	global_position = start_position
	velocity = Vector2.ZERO
	_dash_time_left = 0.0
	_dash_distance_left = 0.0
	_dash_cooldown = 0.0
	_invulnerable_left = 0.0
	_dash_was_down = false
	_action_animation = &""
	_base_animation = &"idle"
	_crossbar_state = CrossbarInputState.READY
	_crossbar_hold_time = 0.0
	_crossbar_was_down = false
	_crossbar_aim_direction = Vector2.UP
	_defeated = false
	_defeat_time_left = 0.0
	_death_emitted = false
	_clear_pending_crossbar_impact()
	if is_instance_valid(_body):
		_body.offset = Vector2.ZERO
		_body.play(&"idle")
	if is_instance_valid(_crossbar_pivot):
		_crossbar_pivot.visible = false
	if restore_hit_points:
		hit_points = 30
		hit_points_changed.emit(hit_points)


func _physics_process(delta: float) -> void:
	if _defeated:
		_update_defeat(delta)
		return
	if not controls_enabled:
		velocity = Vector2.ZERO
		_update_visual_state(Vector2.ZERO)
		return

	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)

	var input_dir := _read_move_input()
	if input_dir.length_squared() > 0.0:
		_last_move_dir = input_dir

	_update_crossbar_input(delta)

	var dash_down := Input.is_key_pressed(KEY_SPACE)
	var dash_started := (
		dash_enabled
		and dash_down
		and not _dash_was_down
		and _dash_cooldown <= 0.0
		and _crossbar_state != CrossbarInputState.RECOVERING
	)
	if dash_started:
		if _is_crossbar_aim_active():
			_cancel_crossbar_aim()
		_dash_time_left = DASH_TIME
		_dash_distance_left = DASH_DISTANCE
		_dash_cooldown = DASH_COOLDOWN
		play_action(&"dash")
	_dash_was_down = dash_down

	var dash_active := _dash_time_left > 0.0 and _dash_distance_left > 0.0
	if dash_active:
		var dash_step := minf(DASH_SPEED * delta, _dash_distance_left)
		velocity = _last_move_dir * (dash_step / delta) if delta > 0.0 else Vector2.ZERO
		_dash_distance_left = maxf(0.0, _dash_distance_left - dash_step)
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
	else:
		var move_speed := SPEED
		if _crossbar_state == CrossbarInputState.AIMING:
			move_speed *= CROSSBAR_AIM_SPEED_FACTOR
		velocity = input_dir * move_speed
	move_and_slide()
	global_position = global_position.clamp(ARENA_RECT.position, ARENA_RECT.end)

	_update_visual_state(input_dir)


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


func _update_crossbar_input(delta: float) -> void:
	var crossbar_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_advance_crossbar_input(crossbar_down, delta)


func _advance_crossbar_input(crossbar_down: bool, delta: float) -> void:
	if not crossbar_enabled:
		if _is_crossbar_aim_active():
			_cancel_crossbar_aim()
		if _crossbar_state == CrossbarInputState.CANCELLED and not crossbar_down:
			_crossbar_state = CrossbarInputState.READY
		_crossbar_was_down = crossbar_down
		return

	if _crossbar_state == CrossbarInputState.PRESSING and _crossbar_was_down:
		_crossbar_hold_time += delta
		if _crossbar_hold_time >= CROSSBAR_HOLD_THRESHOLD:
			_crossbar_state = CrossbarInputState.AIMING

	if crossbar_down and not _crossbar_was_down:
		_start_crossbar_aim()
	elif crossbar_down:
		if _is_crossbar_aim_active():
			_update_crossbar_aim_direction()
			_hold_crossbar_at_aim_frame()
	elif _crossbar_was_down:
		_release_crossbar()

	_crossbar_was_down = crossbar_down


func _start_crossbar_aim() -> void:
	if _crossbar_state != CrossbarInputState.READY:
		return
	if _dash_time_left > 0.0 or _action_animation != &"":
		return
	_crossbar_state = CrossbarInputState.PRESSING
	_crossbar_hold_time = 0.0
	_clear_pending_crossbar_impact()
	_update_crossbar_aim_direction()
	crossbar_action_started.emit(&"crossbar_aim")
	_crossbar_pivot.visible = true
	play_action(&"crossbar_aim", _crossbar_aim_direction)


func _release_crossbar() -> void:
	if _crossbar_state == CrossbarInputState.PRESSING:
		_crossbar_state = CrossbarInputState.RECOVERING
		_queue_crossbar_impact(false)
		_switch_crossbar_animation(&"crossbar_drive")
		crossbar_short_committed.emit(global_position)
	elif _crossbar_state == CrossbarInputState.AIMING:
		_update_crossbar_aim_direction()
		_crossbar_state = CrossbarInputState.RECOVERING
		_queue_crossbar_impact(true)
		_resume_body_animation()
		crossbar_long_committed.emit(global_position, _crossbar_aim_direction)
	elif _crossbar_state == CrossbarInputState.CANCELLED:
		_crossbar_state = CrossbarInputState.READY


func _update_crossbar_aim_direction() -> void:
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() > 0.0:
		_crossbar_aim_direction = direction.normalized()
		_last_move_dir = _crossbar_aim_direction


func _hold_crossbar_at_aim_frame() -> void:
	if not is_instance_valid(_body):
		return
	if _body.animation == &"crossbar_aim" and _body.frame >= CROSSBAR_HOLD_FRAME:
		_body.set_frame_and_progress(CROSSBAR_HOLD_FRAME, 0.0)
		_body.pause()


func _resume_body_animation() -> void:
	if not is_instance_valid(_body):
		return
	var current_frame := _body.frame
	var current_progress := _body.frame_progress
	_body.play(_body.animation)
	_body.set_frame_and_progress(current_frame, current_progress)


func _switch_crossbar_animation(animation_name: StringName) -> void:
	if not is_instance_valid(_body):
		return
	crossbar_action_started.emit(animation_name)
	var current_frame := _body.frame
	var current_progress := _body.frame_progress
	_action_animation = animation_name
	_body.play(animation_name)
	_body.set_frame_and_progress(current_frame, current_progress)


func _queue_crossbar_impact(is_oriented: bool) -> void:
	_crossbar_impact_pending = true
	_crossbar_impact_origin = global_position
	_crossbar_impact_direction = _crossbar_aim_direction
	_crossbar_impact_is_oriented = is_oriented


func _emit_pending_crossbar_impact() -> void:
	if not _crossbar_impact_pending:
		return
	_crossbar_impact_pending = false
	_crossbar_pivot.visible = false
	crossbar_drive_impact.emit(
		_crossbar_impact_origin,
		_crossbar_impact_direction,
		_crossbar_impact_is_oriented,
	)


func _clear_pending_crossbar_impact() -> void:
	_crossbar_impact_pending = false
	_crossbar_impact_origin = Vector2.ZERO
	_crossbar_impact_direction = Vector2.UP
	_crossbar_impact_is_oriented = false


func _is_crossbar_aim_active() -> bool:
	return (
		_crossbar_state == CrossbarInputState.PRESSING
		or _crossbar_state == CrossbarInputState.AIMING
	)


func _cancel_crossbar_aim() -> void:
	if not _is_crossbar_aim_active():
		return
	_crossbar_state = CrossbarInputState.CANCELLED
	_crossbar_hold_time = 0.0
	_crossbar_pivot.visible = false
	crossbar_aim_cancelled.emit()


func take_hit(amount: int = 1) -> void:
	if _defeated or is_invulnerable():
		return
	if _is_crossbar_aim_active():
		_cancel_crossbar_aim()
	elif _crossbar_state == CrossbarInputState.RECOVERING:
		_crossbar_state = CrossbarInputState.READY
		_crossbar_hold_time = 0.0
		_clear_pending_crossbar_impact()
		_crossbar_pivot.visible = false
	hit_points = max(0, hit_points - amount)
	_invulnerable_left = INVULNERABLE_TIME
	hit_points_changed.emit(hit_points)
	if hit_points <= 0:
		_start_defeat()
	else:
		play_action(&"hit")


func _start_defeat() -> void:
	_defeated = true
	_defeat_time_left = DEFEAT_TIME
	_death_emitted = false
	velocity = Vector2.ZERO
	_dash_time_left = 0.0
	_dash_distance_left = 0.0
	_crossbar_state = CrossbarInputState.READY
	_crossbar_hold_time = 0.0
	_crossbar_was_down = false
	_clear_pending_crossbar_impact()
	_crossbar_pivot.visible = false
	_action_animation = &"defeat"
	_body.offset = Vector2.ZERO
	_body.modulate = Color.WHITE
	_body.play(&"defeat")
	defeat_started.emit()


func _update_defeat(delta: float) -> void:
	velocity = Vector2.ZERO
	_defeat_time_left = maxf(0.0, _defeat_time_left - delta)
	if _defeat_time_left <= 0.0 and not _death_emitted:
		_death_emitted = true
		died.emit()


func is_invulnerable() -> bool:
	return _defeated or _invulnerable_left > 0.0


func is_defeated() -> bool:
	return _defeated


func play_action(animation_name: StringName, facing_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_body):
		return
	if not _body.sprite_frames.has_animation(animation_name):
		return
	if (
		_crossbar_state != CrossbarInputState.READY
		and not animation_name in [&"crossbar_aim", &"crossbar_drive", &"dash", &"hit", &"defeat"]
	):
		return
	if facing_direction.length_squared() > 0.0:
		_last_move_dir = facing_direction.normalized()
		_update_visual_rotation()
	_action_animation = animation_name
	_body.play(animation_name)
	if animation_name == &"dash":
		_update_dash_frame_offset()
	else:
		_body.offset = Vector2.ZERO


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
	if _defeated:
		return
	if _action_animation == &"":
		return
	if _action_animation in [&"crossbar_aim", &"crossbar_drive"]:
		_emit_pending_crossbar_impact()
		_crossbar_state = CrossbarInputState.READY
		_crossbar_hold_time = 0.0
		_crossbar_pivot.visible = false
	_action_animation = &""
	_body.offset = Vector2.ZERO
	_body.play(_base_animation)


func _on_body_frame_changed() -> void:
	if _body.animation == &"dash":
		_update_dash_frame_offset()
	elif _crossbar_state == CrossbarInputState.AIMING:
		_hold_crossbar_at_aim_frame()
	elif (
		_crossbar_state == CrossbarInputState.RECOVERING
		and _body.animation in [&"crossbar_aim", &"crossbar_drive"]
		and _body.frame >= CROSSBAR_IMPACT_FRAME
	):
		_emit_pending_crossbar_impact()


func _update_dash_frame_offset() -> void:
	var frame_index := clampi(_body.frame, 0, DASH_FRAME_OFFSETS.size() - 1)
	_body.offset = DASH_FRAME_OFFSETS[frame_index]



