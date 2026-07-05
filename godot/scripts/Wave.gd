class_name Wave
extends Node2D

signal expired(wave)

var wave_owner := "enemy"
var wave_kind := "red"
var radius := 0.0
var speed := 120.0
var lifetime := 7.0
var max_radius := 900.0
var crest_spacing := 54.0
var crest_width := 12.0
var phase := 0.0
var color := Color.RED
var age := 0.0


func setup(new_owner: String, new_kind: String, origin: Vector2, config: Dictionary = {}) -> void:
	wave_owner = new_owner
	wave_kind = new_kind
	global_position = origin

	if wave_owner == "player":
		color = Color(0.44, 0.19, 1.0)
		speed = 255.0
		lifetime = 2.35
		crest_spacing = 42.0
		crest_width = 14.0
		max_radius = 640.0
		phase = PI
	elif wave_kind == "gold":
		color = Color(1.0, 0.78, 0.33)
		speed = 95.0
		lifetime = 8.0
		crest_spacing = 70.0
		crest_width = 16.0
		max_radius = 920.0
		phase = PI * 0.35
	else:
		color = Color(1.0, 0.06, 0.13)
		speed = 118.0
		lifetime = 7.2
		crest_spacing = 56.0
		crest_width = 12.0
		max_radius = 920.0
		phase = 0.0

	speed = config.get("speed", speed)
	lifetime = config.get("lifetime", lifetime)
	crest_spacing = config.get("crest_spacing", crest_spacing)
	crest_width = config.get("crest_width", crest_width)
	max_radius = config.get("max_radius", max_radius)


func _process(delta: float) -> void:
	age += delta
	radius += speed * delta
	if age >= lifetime or radius > max_radius:
		expired.emit(self)
		queue_free()
	queue_redraw()


func get_crest_radii() -> Array[float]:
	if radius <= 8.0:
		return []
	return [radius]


func is_crest_at(global_point: Vector2, margin: float = 0.0) -> bool:
	var distance := global_position.distance_to(global_point)
	for crest_radius in get_crest_radii():
		if absf(distance - crest_radius) <= crest_width * 0.5 + margin:
			return true
	return false


func crest_closeness(global_point: Vector2) -> float:
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
			_draw_enemy_crest(crest_radius, crest_index, is_front, local_alpha)
		else:
			_draw_player_crest(crest_radius, is_front, local_alpha)


func _draw_enemy_crest(crest_radius: float, crest_index: int, is_front: bool, local_alpha: float) -> void:
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


func _draw_player_crest(crest_radius: float, is_front: bool, local_alpha: float) -> void:
	var glow_color := color
	glow_color.a = (0.10 if is_front else 0.05) * local_alpha
	var line_color := color
	line_color.a = (0.78 if is_front else 0.42) * local_alpha
	var core_color := Color(0.82, 0.75, 1.0, (0.42 if is_front else 0.20) * local_alpha)

	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, glow_color, crest_width * 2.0, true)
	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, line_color, crest_width * 0.85, true)
	draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, core_color, 2.0, true)

