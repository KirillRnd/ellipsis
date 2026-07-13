class_name WaveEmitter
extends Node2D

signal defeated(emitter)

@export var wave_kind := "red"
@export var interval := 2.4
@export var initial_delay := 0.5
@export var active_at := 0.0
@export var max_hit_points := 8

const TELEGRAPH_TIME := 0.55
const RED_REACH_RADIUS := Wave.RED_MAX_RADIUS
const GOLD_REACH_LENGTH := Wave.GOLD_MAX_RADIUS
const GOLD_REACH_HALF_WIDTH := Wave.GOLD_LINE_HALF_LENGTH
const HITBOX_RADIUS := 7.0
const HITBOX_DOT_RADIUS := 5.0
const TIMER_BAR_HEIGHT := 7.0
const RED_EMITTER_TEXTURE := preload("res://assets/actors/emitter_red_base.png")
const GOLD_BOSS_TEXTURE := preload("res://assets/actors/boss_golden_knight_topdown.png")

var wave_manager
var wave_config := {}
var damage_mode := "direct"
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
	return _is_active() and damage_mode != "none"


func can_take_direct_damage() -> bool:
	return can_take_damage() and damage_mode == "direct"


func can_take_boost_damage() -> bool:
	return can_take_damage() and damage_mode in ["direct", "boost_only"]


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
	wave_manager.spawn_wave("enemy", wave_kind, global_position, wave_config)


func _draw() -> void:
	var active := _is_active()
	var base_color := Color(1.0, 0.08, 0.14) if wave_kind == "red" else Color(1.0, 0.78, 0.36)
	var alpha := 1.0 if active else 0.16
	if is_destroyed():
		alpha = 0.06
	var charge := 0.0
	if active and _cooldown <= TELEGRAPH_TIME:
		charge = 1.0 - clampf(_cooldown / TELEGRAPH_TIME, 0.0, 1.0)

	_draw_damage_reach(base_color, active)
	_draw_sprite_body(alpha)
	if _hit_flash > 0.0:
		draw_arc(Vector2.ZERO, HITBOX_RADIUS + 8.0, 0.0, TAU, 48, Color(0.80, 0.92, 1.0, 0.70), 3.0, true)
	_draw_hitbox(base_color, alpha)
	_draw_wave_timer(base_color, active, charge)
	if damage_mode != "none":
		_draw_hp_bar()


func _draw_damage_reach(base_color: Color, active: bool) -> void:
	if is_destroyed():
		return
	var fill := base_color
	fill.a = 0.040 if active else 0.018
	var edge := base_color
	edge.a = 0.24 if active else 0.10
	if wave_kind == "gold":
		_draw_line_damage_reach(fill, edge)
	else:
		var reach_radius: float = wave_config.get("max_radius", RED_REACH_RADIUS)
		draw_circle(Vector2.ZERO, reach_radius, fill)
		draw_arc(Vector2.ZERO, reach_radius, 0.0, TAU, 192, edge, 2.0, true)


func _draw_line_damage_reach(fill: Color, edge: Color) -> void:
	var direction := Vector2.DOWN
	var tangent := Vector2.RIGHT
	var reach_length: float = wave_config.get("max_radius", GOLD_REACH_LENGTH)
	var half_width: float = wave_config.get("line_half_length", GOLD_REACH_HALF_WIDTH)
	var front := direction * reach_length
	var points: PackedVector2Array = [
		-tangent * half_width,
		tangent * half_width,
		front + tangent * half_width,
		front - tangent * half_width,
	]
	draw_colored_polygon(points, fill)
	for i in range(points.size()):
		draw_line(points[i], points[(i + 1) % points.size()], edge, 2.0, true)


func _draw_sprite_body(alpha: float) -> void:
	var texture = GOLD_BOSS_TEXTURE if wave_kind == "gold" else RED_EMITTER_TEXTURE
	var size := Vector2(76, 76) if wave_kind == "gold" else Vector2(68, 68)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))


func _draw_hitbox(base_color: Color, alpha: float) -> void:
	var visibility := maxf(alpha, 0.42)
	var fill := base_color.lerp(Color.WHITE, 0.35)
	fill.a = 0.72 * visibility
	var edge := base_color.lerp(Color.WHITE, 0.20)
	edge.a = 0.95 * visibility
	draw_circle(Vector2.ZERO, HITBOX_DOT_RADIUS, fill)
	draw_arc(Vector2.ZERO, HITBOX_RADIUS, 0.0, TAU, 48, edge, 2.0, true)


func _draw_wave_timer(base_color: Color, active: bool, charge: float) -> void:
	var width := 76.0 if wave_kind == "red" else 96.0
	var pos := Vector2(-width * 0.5, -55.0)
	var bg := Rect2(pos, Vector2(width, TIMER_BAR_HEIGHT))
	draw_rect(bg, Color(0.02, 0.015, 0.025, 0.88))

	if active and interval > 0.0:
		var ready := 1.0 - clampf(_cooldown / interval, 0.0, 1.0)
		var fill := base_color.lerp(Color.WHITE, 0.45 * charge)
		fill.a = 0.88
		draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2((width - 2.0) * ready, TIMER_BAR_HEIGHT - 2.0)), fill)
		if charge > 0.0:
			var alert := Color(1.0, 1.0, 1.0, 0.45 * charge)
			draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2(width - 2.0, TIMER_BAR_HEIGHT - 2.0)), alert, false, 1.0)

	for tick in range(1, 4):
		var x := pos.x + width * float(tick) / 4.0
		draw_line(Vector2(x, pos.y + 1.0), Vector2(x, pos.y + TIMER_BAR_HEIGHT - 1.0), Color(0.92, 0.88, 0.82, 0.24), 1.0, false)
	draw_rect(bg, Color(0.92, 0.88, 0.82, 0.55 if active else 0.22), false, 1.0)


func _draw_hp_bar() -> void:
	var width := 54.0
	var ratio := 0.0 if max_hit_points <= 0 else float(hit_points) / float(max_hit_points)
	var bg := Rect2(Vector2(-width * 0.5, -42.0), Vector2(width, 5.0))
	draw_rect(bg, Color(0.02, 0.015, 0.025, 0.85))
	draw_rect(Rect2(bg.position, Vector2(width * ratio, 5.0)), Color(0.26, 0.78, 1.0, 0.90))
	draw_rect(bg, Color(0.82, 0.92, 1.0, 0.55), false, 1.0)
