class_name Wave
extends Node2D

signal expired(wave)

const PLAYER_MAX_RADIUS := 300.0
const RED_MAX_RADIUS := 425.0
const GOLD_MAX_RADIUS := 430.0
const GOLD_LINE_HALF_LENGTH := 700.0
const SHARED_SPEED := 118.0
const SHARED_CREST_WIDTH := 14.0

var wave_owner := "enemy"
var wave_kind := "red"
var wave_shape := "circle"
var radius := 0.0
var speed := SHARED_SPEED
var lifetime := 7.0
var max_radius := 900.0
var crest_spacing := 54.0
var crest_width := 12.0
var phase := 0.0
var color := Color.RED
var age := 0.0
var line_direction := Vector2.DOWN
var line_half_length := 720.0
var can_damage_emitters := true
var can_create_resonance := true
var damaged_emitters := {}


func setup(new_owner: String, new_kind: String, origin: Vector2, config: Dictionary = {}) -> void:
	wave_owner = new_owner
	wave_kind = new_kind
	global_position = origin
	wave_shape = "circle"
	line_direction = Vector2.DOWN
	can_damage_emitters = true
	can_create_resonance = true

	if wave_owner == "player":
		if wave_kind == "blue":
			color = Color(0.24, 0.72, 1.0)
			can_damage_emitters = false
			can_create_resonance = false
		else:
			color = Color(0.44, 0.19, 1.0)
		speed = SHARED_SPEED
		lifetime = 2.35
		crest_spacing = 42.0
		crest_width = SHARED_CREST_WIDTH
		max_radius = PLAYER_MAX_RADIUS
		phase = PI
	elif wave_kind == "gold":
		wave_shape = "line"
		color = Color(1.0, 0.78, 0.33)
		speed = SHARED_SPEED
		lifetime = 8.0
		crest_spacing = 70.0
		crest_width = SHARED_CREST_WIDTH
		max_radius = GOLD_MAX_RADIUS
		line_half_length = GOLD_LINE_HALF_LENGTH
		phase = PI * 0.35
	else:
		color = Color(1.0, 0.06, 0.13)
		speed = SHARED_SPEED
		lifetime = 7.2
		crest_spacing = 56.0
		crest_width = SHARED_CREST_WIDTH
		max_radius = RED_MAX_RADIUS
		phase = 0.0

	lifetime = config.get("lifetime", lifetime)
	crest_spacing = config.get("crest_spacing", crest_spacing)
	crest_width = config.get("crest_width", crest_width)
	max_radius = config.get("max_radius", max_radius)
	line_direction = config.get("line_direction", line_direction).normalized()
	line_half_length = config.get("line_half_length", line_half_length)
	can_damage_emitters = config.get("can_damage_emitters", can_damage_emitters)
	can_create_resonance = config.get("can_create_resonance", can_create_resonance)


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


func _draw_enemy_front(crest_radius: float, _crest_index: int, is_front: bool, local_alpha: float) -> void:
	if wave_shape == "line":
		_draw_enemy_line_front(crest_radius, is_front, local_alpha)
	else:
		_draw_circle_crest(crest_radius, is_front, local_alpha)


func _draw_circle_crest(crest_radius: float, is_front: bool, local_alpha: float) -> void:
	var glow_color := color
	glow_color.a = (0.10 if is_front else 0.05) * local_alpha
	var line_color := color
	line_color.a = (0.78 if is_front else 0.42) * local_alpha
	var core_color := _crest_core_color(local_alpha, is_front)

	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, glow_color, crest_width * 2.0, true)
	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, line_color, crest_width * 0.85, true)
	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, core_color, 2.0, true)


func _draw_enemy_line_front(crest_radius: float, is_front: bool, local_alpha: float) -> void:
	var center := line_direction * crest_radius
	var tangent := Vector2(-line_direction.y, line_direction.x)
	var start := center - tangent * line_half_length
	var end := center + tangent * line_half_length
	var glow_color := color
	glow_color.a = (0.10 if is_front else 0.05) * local_alpha
	var line_color := color
	line_color.a = (0.78 if is_front else 0.42) * local_alpha
	var core_color := _crest_core_color(local_alpha, is_front)

	draw_line(start, end, glow_color, crest_width * 2.0, true)
	draw_line(start, end, line_color, crest_width * 0.85, true)
	draw_line(start, end, core_color, 2.0, true)


func _draw_player_crest(crest_radius: float, is_front: bool, local_alpha: float) -> void:
	_draw_circle_crest(crest_radius, is_front, local_alpha)


func _crest_core_color(local_alpha: float, is_front: bool) -> Color:
	var core_color := color.lerp(Color.WHITE, 0.68)
	core_color.a = (0.42 if is_front else 0.20) * local_alpha
	return core_color
