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
	var radii: Array[float] = []
	for i in range(8):
		var crest_radius := radius - float(i) * crest_spacing
		if crest_radius > 8.0:
			radii.append(crest_radius)
	return radii


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
	for crest_radius in get_crest_radii():
		var local_alpha := fade * clampf(crest_radius / 90.0, 0.35, 1.0)
		var glow_color := color
		glow_color.a = 0.12 * local_alpha
		var line_color := color
		line_color.a = 0.82 * local_alpha
		var core_color := Color(1.0, 0.92, 1.0, 0.5 * local_alpha)

		draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, glow_color, crest_width * 2.8, true)
		draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, line_color, crest_width, true)
		draw_arc(Vector2.ZERO, crest_radius, 0.0, TAU, 160, core_color, 2.0, true)

