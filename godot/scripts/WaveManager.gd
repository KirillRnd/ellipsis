class_name WaveManager
extends Node2D

signal danger_changed(danger_value: int)

const WAVE_SCENE := preload("res://scenes/Wave.tscn")
const ARENA_RECT := Rect2(Vector2(80, 60), Vector2(1120, 600))

var player
var waves: Array = []
var player_wave
var _last_danger_value := 0


func spawn_wave(wave_owner: String, wave_kind: String, origin: Vector2, config: Dictionary = {}):
	if wave_owner == "player" and is_instance_valid(player_wave):
		player_wave.queue_free()
		waves.erase(player_wave)

	var wave = WAVE_SCENE.instantiate()
	add_child(wave)
	wave.setup(wave_owner, wave_kind, origin, config)
	wave.expired.connect(_on_wave_expired)
	waves.append(wave)
	if wave_owner == "player":
		player_wave = wave
	return wave


func _process(_delta: float) -> void:
	_cleanup_dead_waves()
	if is_instance_valid(player):
		var danger := get_point_danger(player.global_position)
		if danger != _last_danger_value:
			_last_danger_value = danger
			danger_changed.emit(danger)
		if danger > 0:
			player.take_hit()
	queue_redraw()


func get_point_danger(global_point: Vector2) -> int:
	var enemy_wave = _first_enemy_crest_at(global_point, 7.0)
	if enemy_wave == null:
		return 0

	if is_instance_valid(player_wave) and player_wave.is_crest_at(global_point, 24.0):
		return _interference_result(global_point, enemy_wave, player_wave)

	return 1


func _first_enemy_crest_at(global_point: Vector2, margin: float):
	for wave in waves:
		if not is_instance_valid(wave):
			continue
		if wave.wave_owner == "enemy" and wave.is_crest_at(global_point, margin):
			return wave
	return null


func _interference_result(global_point: Vector2, enemy_wave, counter_wave) -> int:
	var mix := sin(global_point.x * 0.025 + global_point.y * 0.019 + enemy_wave.radius * 0.018 - counter_wave.radius * 0.021)
	if mix > 0.78:
		return 2
	return -1


func _draw() -> void:
	if not is_instance_valid(player_wave):
		return

	for enemy_wave in waves:
		if not is_instance_valid(enemy_wave) or enemy_wave.wave_owner != "enemy":
			continue
		_draw_interference_between(enemy_wave, player_wave)


func _draw_interference_between(enemy_wave, counter_wave) -> void:
	for enemy_radius in enemy_wave.get_crest_radii():
		for counter_radius in counter_wave.get_crest_radii():
			if not _circles_can_intersect(enemy_wave.global_position, enemy_radius, counter_wave.global_position, counter_radius):
				continue
			var points := _circle_intersections(enemy_wave.global_position, enemy_radius, counter_wave.global_position, counter_radius)
			for point in points:
				if not ARENA_RECT.has_point(point):
					continue
				var result := _interference_result(point, enemy_wave, counter_wave)
				if result < 0:
					_draw_safe_cut(enemy_wave.global_position, enemy_radius, point)
				else:
					_draw_danger_node(point)


func _circles_can_intersect(a: Vector2, ar: float, b: Vector2, br: float) -> bool:
	var d := a.distance_to(b)
	return d > 0.01 and d <= ar + br and d >= absf(ar - br)


func _circle_intersections(a: Vector2, ar: float, b: Vector2, br: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var delta := b - a
	var d := delta.length()
	if d <= 0.01:
		return result

	var along := (ar * ar - br * br + d * d) / (2.0 * d)
	var height_sq := ar * ar - along * along
	if height_sq < 0.0:
		return result

	var dir := delta / d
	var base := a + dir * along
	var normal := Vector2(-dir.y, dir.x)
	var height := sqrt(height_sq)
	result.append(base + normal * height)
	if height > 0.5:
		result.append(base - normal * height)
	return result


func _draw_safe_cut(center: Vector2, radius: float, point: Vector2) -> void:
	var angle := (point - center).angle()
	var width := 0.22
	var dark := Color(0.002, 0.006, 0.020, 0.90)
	var rim := Color(0.12, 0.28, 0.85, 0.55)
	draw_arc(center, radius, angle - width, angle + width, 24, dark, 34.0, true)
	draw_arc(center, radius, angle - width, angle + width, 24, rim, 4.0, true)
	draw_circle(point, 7.0, Color(0.02, 0.06, 0.16, 0.80))


func _draw_danger_node(point: Vector2) -> void:
	draw_circle(point, 30.0, Color(1.0, 0.10, 0.42, 0.20))
	draw_circle(point, 15.0, Color(1.0, 0.35, 0.62, 0.55))
	draw_circle(point, 6.0, Color(1.0, 0.92, 0.98, 0.95))
	draw_line(point + Vector2(-18, 0), point + Vector2(18, 0), Color(1.0, 0.80, 0.95, 0.65), 2.0, true)
	draw_line(point + Vector2(0, -18), point + Vector2(0, 18), Color(1.0, 0.80, 0.95, 0.65), 2.0, true)


func _on_wave_expired(wave) -> void:
	waves.erase(wave)
	if wave == player_wave:
		player_wave = null


func _cleanup_dead_waves() -> void:
	for i in range(waves.size() - 1, -1, -1):
		if not is_instance_valid(waves[i]):
			waves.remove_at(i)
