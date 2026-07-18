class_name RahnBoss
extends CharacterBody2D

signal hit_points_changed(current: int, maximum: int)
signal defeated(boss)

const RED_RESONATOR_SCENE := preload("res://scenes/RedResonator.tscn")
const ANCHOR_TEXTURE := preload("res://assets/actors/rahn/rahn_anchor.png")
const MOVE_TEXTURE := preload("res://assets/actors/rahn/rahn_move_sheet.png")
const ACTION_TEXTURE := preload("res://assets/actors/rahn/rahn_action_sheet.png")
const DEFEAT_TEXTURE := preload("res://assets/actors/rahn/rahn_defeat_sheet.png")
const ARENA_RECT := Rect2(Vector2(130.0, 110.0), Vector2(1020.0, 500.0))
const FRAME_SIZE := Vector2(288.0, 288.0)
const FIRST_PLACE_DELAY := 0.65
const SECOND_PLACE_DELAY := 0.58
const DEFEAT_TIME := 0.65
const MOVE_START_DISTANCE := 18.0
const MOVE_STOP_DISTANCE := 8.0
const TURN_RESPONSE := 8.0

@export var max_hit_points := 70
@export var move_speed := 185.0
@export var volley_interval := 2.35
@export var reposition_interval := 6.8
@export var resonator_forward_distance := 118.0
@export var resonator_side_distance := 102.0

@onready var _visual_root: Node2D = $VisualRoot
@onready var _body: AnimatedSprite2D = $VisualRoot/Body

var player
var wave_manager
var combat_running := false
var hit_points := 70

var _active_resonators: Array[RedResonator] = []
var _placement_count := 0
var _place_timer := FIRST_PLACE_DELAY
var _volley_timer := 0.0
var _reposition_timer := 0.0
var _combat_age := 0.0
var _was_running := false
var _moving := false
var _action_playing := false
var _hit_flash := 0.0
var _defeated := false
var _defeat_time_left := 0.0
var _defeat_emitted := false


func _ready() -> void:
	_build_sprite_frames()
	_body.animation_finished.connect(_on_animation_finished)
	hit_points = max_hit_points
	_body.play(&"anchor")
	hit_points_changed.emit(hit_points, max_hit_points)


func _exit_tree() -> void:
	_clear_resonators()


func _physics_process(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if is_instance_valid(_body):
		_body.modulate = Color(1.0, 0.48, 0.48) if _hit_flash > 0.0 else Color.WHITE

	if _defeated:
		velocity = Vector2.ZERO
		_moving = false
		_defeat_time_left = maxf(0.0, _defeat_time_left - delta)
		if _defeat_time_left <= 0.0 and not _defeat_emitted:
			_defeat_emitted = true
			defeated.emit(self)
		return

	if not combat_running:
		velocity = Vector2.ZERO
		_moving = false
		_was_running = false
		_update_animation()
		return

	if not _was_running:
		_was_running = true
		_place_timer = FIRST_PLACE_DELAY
		_volley_timer = volley_interval
		_reposition_timer = reposition_interval

	_combat_age += delta
	_update_movement(delta)
	_update_resonator_plan(delta)
	_update_animation()


func _update_movement(delta: float) -> void:
	var target := Vector2(
		640.0 + cos(_combat_age * 0.72) * 270.0,
		250.0 + sin(_combat_age * 0.51) * 105.0
	)
	var offset := target - global_position
	var distance := offset.length()
	if _moving:
		_moving = distance > MOVE_STOP_DISTANCE
	else:
		_moving = distance > MOVE_START_DISTANCE
	velocity = offset.normalized() * move_speed if _moving else Vector2.ZERO
	move_and_slide()
	global_position = global_position.clamp(ARENA_RECT.position, ARENA_RECT.end)
	if velocity.length_squared() > 1.0:
		var target_rotation := velocity.angle() + PI * 0.5
		_visual_root.rotation = lerp_angle(
			_visual_root.rotation,
			target_rotation,
			clampf(delta * TURN_RESPONSE, 0.0, 1.0)
		)


func _update_resonator_plan(delta: float) -> void:
	if _active_resonators.size() < 2:
		_place_timer -= delta
		if _place_timer <= 0.0:
			var side := 1.0 if _active_resonators.is_empty() else -1.0
			_place_resonator(_resonator_position(side))
			_place_timer = SECOND_PLACE_DELAY
			if _active_resonators.size() == 2:
				_volley_timer = 0.35
				_reposition_timer = reposition_interval
		return

	_volley_timer -= delta
	_reposition_timer -= delta
	if _volley_timer <= 0.0:
		_fire_volley()
		_volley_timer += volley_interval
	if _reposition_timer <= 0.0:
		var side := 1.0 if _placement_count % 2 == 0 else -1.0
		_place_resonator(_resonator_position(side))
		_reposition_timer += reposition_interval


func _resonator_position(side: float) -> Vector2:
	var direction := Vector2.DOWN
	if is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length_squared() > 1.0:
			direction = to_player.normalized()
	var tangent := Vector2(-direction.y, direction.x)
	var target := (
		global_position
		+ direction * resonator_forward_distance
		+ tangent * resonator_side_distance * side
	)
	return target.clamp(ARENA_RECT.position, ARENA_RECT.end)


func _place_resonator(target: Vector2) -> void:
	if _active_resonators.size() >= 2:
		var oldest: RedResonator = _active_resonators.pop_front()
		if is_instance_valid(oldest):
			oldest.visible = false
			oldest.queue_free()
	var resonator: RedResonator = RED_RESONATOR_SCENE.instantiate()
	resonator.name = "RahnResonator%d" % (_placement_count + 1)
	resonator.global_position = target
	get_parent().add_child(resonator)
	_active_resonators.append(resonator)
	_placement_count += 1
	_play_action()


func _fire_volley() -> void:
	if not is_instance_valid(wave_manager):
		return
	for resonator in _active_resonators:
		if not is_instance_valid(resonator):
			continue
		wave_manager.spawn_wave("enemy", "red", resonator.global_position)
		resonator.trigger()
	_play_action()


func can_take_damage() -> bool:
	return combat_running and not _defeated


func can_take_direct_damage() -> bool:
	return can_take_damage()


func can_take_resonance_damage() -> bool:
	return can_take_damage()


func get_hitbox_radius() -> float:
	return 22.0


func take_damage(amount: int) -> void:
	if not can_take_damage():
		return
	hit_points = maxi(0, hit_points - amount)
	_hit_flash = 0.15
	hit_points_changed.emit(hit_points, max_hit_points)
	if hit_points <= 0:
		_start_defeat()


func _start_defeat() -> void:
	_defeated = true
	combat_running = false
	velocity = Vector2.ZERO
	_action_playing = false
	_defeat_time_left = DEFEAT_TIME
	_defeat_emitted = false
	_clear_resonators()
	_body.modulate = Color.WHITE
	_body.play(&"defeat")


func _clear_resonators() -> void:
	for resonator in _active_resonators:
		if is_instance_valid(resonator):
			resonator.visible = false
			resonator.queue_free()
	_active_resonators.clear()


func _play_action() -> void:
	if _defeated or _action_playing:
		return
	_action_playing = true
	_body.play(&"action")


func _update_animation() -> void:
	if _action_playing or _defeated:
		return
	var next := &"move" if _moving else &"anchor"
	if _body.animation != next:
		_body.play(next)


func _on_animation_finished() -> void:
	if _defeated or _body.animation != &"action":
		return
	_action_playing = false
	_update_animation()


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"anchor", ANCHOR_TEXTURE, 1, 1.0, true)
	_add_animation(frames, &"move", MOVE_TEXTURE, 4, 6.5, true)
	_add_animation(frames, &"action", ACTION_TEXTURE, 5, 8.0, false)
	_add_animation(frames, &"defeat", DEFEAT_TEXTURE, 1, 1.0, false)
	_body.sprite_frames = frames


func _add_animation(
	frames: SpriteFrames,
	name: StringName,
	texture: Texture2D,
	frame_count: int,
	speed: float,
	looped: bool
) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, speed)
	frames.set_animation_loop(name, looped)
	for index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(index * FRAME_SIZE.x, 0.0), FRAME_SIZE)
		frames.add_frame(name, atlas)
