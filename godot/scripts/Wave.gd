class_name Wave
extends Node2D

signal expired(wave)

const PLAYER_MAX_RADIUS := 300.0
const RED_MAX_RADIUS := 425.0
const GOLD_MAX_RADIUS := 430.0
const GOLD_LINE_HALF_LENGTH := 700.0

var wave_owner := "enemy"
var wave_kind := "red"
var wave_shape := "circle"
var radius := 0.0
var speed := 120.0
var lifetime := 7.0
var max_radius := 900.0
var crest_spacing := 54.0
var crest_width := 12.0
var phase := 0.0
var color := Color.RED
var age := 0.0
var line_direction := Vector2.DOWN
var line_half_length := 720.0
var damaged_emitters := {}
var boosted_emitters := {}


func setup(new_owner: String, new_kind: String, origin: Vector2, config: Dictionary = {}) -> void:
	wave_owner = new_owner
	wave_kind = new_kind
	global_position = origin
	wave_shape = "circle"
	line_direction = Vector2.DOWN

	if wave_owner == "player":
		color = Color(0.44, 0.19, 1.0)
		speed = 255.0
		lifetime = 2.35
		crest_spacing = 42.0
		crest_width = 14.0
		max_radius = PLAYER_MAX_RADIUS
		phase = PI
	elif wave_kind == "gold":
		wave_shape = "line"
		color = Color(1.0, 0.78, 0.33)
		speed = 105.0
		lifetime = 8.0
		crest_spacing = 70.0
		crest_width = 16.0
		max_radius = GOLD_MAX_RADIUS
		line_half_length = GOLD_LINE_HALF_LENGTH
		phase = PI * 0.35
	else:
		color = Color(1.0, 0.06, 0.13)
		speed = 118.0
		lifetime = 7.2
		crest_spacing = 56.0
		crest_width = 12.0
		max_radius = RED_MAX_RADIUS
		phase = 0.0

	speed = config.get("speed", speed)
	lifetime = config.get("lifetime", lifetime)
	crest_spacing = config.get("crest_spacing", crest_spacing)
	crest_width = config.get("crest_width", crest_width)
	max_radius = config.get("max_radius", max_radius)
	line_direction = config.get("line_direction", line_direction).normalized()
	line_half_length = config.get("line_half_length", line_half_length)


func _process(delta: float) -> void:
	age += delta
	radius += speed * delta
	if age >= lifetime or radius >= max_radius:
		radius = minf(radius, max_radius)
		expired.emit(self)
		queue_free()
		return
	queue_redraw()


func get_crest_radii() -> Array[float]:
	if radius <= 8.0:
		return []
	return [radius]


func is_crest_at(global_point: Vector2, margin: float = 0.0) -> bool:
	if wave_shape == "line":
		return _line_crest_at(global_point, margin)

	var distance := global_position.distance_to(global_point)
	if distance > max_radius:
		return false
	for crest_radius in get_crest_radii():
		if absf(distance - crest_radius) <= crest_width * 0.5 + margin:
			return true
	return false


func _line_crest_at(global_point: Vector2, margin: float) -> bool:
	var local := global_point - global_position
	var along := local.dot(line_direction)
	var tangent := Vector2(-line_direction.y, line_direction.x)
	var side := absf(local.dot(tangent))
	if along < 0.0 or along > max_radius or side > line_half_length:
		return false
	return absf(along - radius) <= crest_width * 0.5 + margin


func crest_closeness(global_point: Vector2) -> float:
	if wave_shape == "line":
		var local := global_point - global_position
		var along := local.dot(line_direction)
		return clampf(1.0 - absf(along - radius) / maxf(crest_width, 1.0), 0.0, 1.0)

	var distance := global_position.distance_to(global_point)
	var best := 99999.0
	for crest_radius in get_crest_radii():
		best = minf(best, absf(distance - crest_radius))
	return clampf(1.0 - best / maxf(crest_width, 1.0), 0.0, 1.0)


func _draw() -> void:
	var fade := clampf(1.0 - age / lifetime, 0.0, 1.0)
	var radii := get_crest_radii()
	for crest_index in range(radii.size()):
		var crest_radius: float = radii[crest_index]
		var is_front := crest_index == 0
		var local_alpha := fade * clampf(crest_radius / 90.0, 0.35, 1.0)
		if wave_owner == "enemy":
			_draw_enemy_front(crest_radius, crest_index, is_front, local_alpha)
		else:
			_draw_player_crest(crest_radius, is_front, local_alpha)


func _draw_enemy_front(crest_radius: float, crest_index: int, is_front: bool, local_alpha: float) -> void:
	if wave_shape == "line":
		_draw_enemy_line_front(crest_radius, is_front, local_alpha)
	else:
		_draw_enemy_circle_front(crest_radius, crest_index, is_front, local_alpha)


func _draw_enemy_circle_front(crest_radius: float, crest_index: int, is_front: bool, local_alpha: float) -> void:
	var crest_alpha := (0.96 if is_front else 0.40) * local_alpha
	var glow_alpha := (0.16 if is_front else 0.05) * local_alpha
	var crest_color := color
	crest_color.a = crest_alpha
	var glow_color := color
	glow_color.a = glow_alpha
	var inner_hot := Color(1.0, 0.74, 0.78, (0.62 if is_front else 0.18) * local_alpha)

	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 192, glow_color, crest_width * (2.2 if is_front else 1.4), true)
	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 192, crest_color, crest_width * (1.05 if is_front else 0.65), true)
	draw_arc(Vector2.ZERO, crest_radius + crest_width * 0.72, 0.0, TAU, 192, inner_hot, 3.0 if is_front else 1.5, true)
	if is_front:
		var leading := Color(1.0, 0.16, 0.20, 0.95 * local_alpha)
		draw_arc(Vector2.ZERO, crest_radius + crest_width * 1.05, 0.0, TAU, 192, leading, 4.0, true)


func _draw_enemy_line_front(crest_radius: float, is_front: bool, local_alpha: float) -> void:
	var center := line_direction * crest_radius
	var tangent := Vector2(-line_direction.y, line_direction.x)
	var start := center - tangent * line_half_length
	var end := center + tangent * line_half_length
	var glow_color := color
	glow_color.a = 0.15 * local_alpha
	var line_color := color
	line_color.a = 0.92 * local_alpha
	var hot := Color(1.0, 0.94, 0.72, 0.72 * local_alpha)

	draw_line(start, end, glow_color, crest_width * 3.0, true)
	draw_line(start, end, line_color, crest_width * 1.15, true)
	draw_line(start, end, hot, 3.5, true)


func _draw_player_crest(crest_radius: float, is_front: bool, local_alpha: float) -> void:
	var glow_color := color
	glow_color.a = (0.10 if is_front else 0.05) * local_alpha
	var line_color := color
	line_color.a = (0.78 if is_front else 0.42) * local_alpha
	var core_color := Color(0.82, 0.75, 1.0, (0.42 if is_front else 0.20) * local_alpha)

	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, glow_color, crest_width * 2.0, true)
	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, line_color, crest_width * 0.85, true)
	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, core_color, 2.0, true)
