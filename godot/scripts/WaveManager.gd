class_name WaveManager
extends Node2D

signal danger_changed(danger_value: int)

const WAVE_SCENE := preload("res://scenes/Wave.tscn")
const ARENA_RECT := Rect2(Vector2(80, 60), Vector2(1120, 600))

var player
var waves: Array = []
var player_waves: Array = []
var _last_danger_value := 0


func spawn_wave(wave_owner: String, wave_kind: String, origin: Vector2, config: Dictionary = {}):
	var wave = WAVE_SCENE.instantiate()
	var host := get_parent()
	if host == null:
		host = self
	host.add_child(wave)
	if host != self:
		host.move_child(wave, get_index())

	wave.setup(wave_owner, wave_kind, origin, config)
	wave.expired.connect(_on_wave_expired)
	waves.append(wave)
	if wave_owner == "player":
		player_waves.append(wave)
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

	for counter_wave in player_waves:
		if not is_instance_valid(counter_wave):
			continue
		if counter_wave.is_crest_at(global_point, 24.0):
			return -1

	return 1


func _first_enemy_crest_at(global_point: Vector2, margin: float):
	for wave in waves:
		if not is_instance_valid(wave):
			continue
		if wave.wave_owner == "enemy" and wave.is_crest_at(global_point, margin):
			return wave
	return null


func _draw() -> void:
	_draw_player_erasure()
	_draw_enemy_interference_nodes()


func _draw_player_erasure() -> void:
	for enemy_wave in waves:
		if not is_instance_valid(enemy_wave) or enemy_wave.wave_owner != "enemy":
			continue
		for counter_wave in player_waves:
			if not is_instance_valid(counter_wave):
				continue
			_draw_erasure_between(enemy_wave, counter_wave)


func _draw_enemy_interference_nodes() -> void:
	var enemies := _enemy_waves()
	for a_index in range(enemies.size()):
		var a = enemies[a_index]
		if not is_instance_valid(a):
			continue
		for b_index in range(a_index + 1, enemies.size()):
			var b = enemies[b_index]
			if not is_instance_valid(b):
				continue
			_draw_nodes_between_enemy_waves(a, b)


func _enemy_waves() -> Array:
	var enemies := []
	for wave in waves:
		if is_instance_valid(wave) and wave.wave_owner == "enemy":
			enemies.append(wave)
	return enemies


func _draw_erasure_between(enemy_wave, counter_wave) -> void:
	for enemy_radius in enemy_wave.get_crest_radii():
		for counter_radius in counter_wave.get_crest_radii():
			if not _circles_can_intersect(enemy_wave.global_position, enemy_radius, counter_wave.global_position, counter_radius):
				continue
			var points := _circle_intersections(enemy_wave.global_position, enemy_radius, counter_wave.global_position, counter_radius)
			for point in points:
				if ARENA_RECT.has_point(point):
					_draw_erased_arc(enemy_wave.global_position, enemy_radius, point)


func _draw_nodes_between_enemy_waves(a, b) -> void:
	for a_radius in a.get_crest_radii():
		for b_radius in b.get_crest_radii():
			if not _circles_can_intersect(a.global_position, a_radius, b.global_position, b_radius):
				continue
			var points := _circle_intersections(a.global_position, a_radius, b.global_position, b_radius)
			for point in points:
				if ARENA_RECT.has_point(point):
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


func _draw_erased_arc(center: Vector2, radius: float, point: Vector2) -> void:
	var angle := (point - center).angle()
	var width := 0.30
	var arena_fill := Color(0.055, 0.052, 0.070, 0.98)
	var edge := Color(0.12, 0.30, 0.90, 0.70)
	draw_arc(center, radius, angle - width, angle + width, 32, arena_fill, 54.0, true)
	draw_arc(center, radius, angle - width, angle + width, 32, edge, 5.0, true)
	draw_circle(point, 12.0, Color(0.025, 0.035, 0.075, 0.92))


func _draw_danger_node(point: Vector2) -> void:
	draw_circle(point, 26.0, Color(1.0, 0.10, 0.42, 0.18))
	draw_circle(point, 13.0, Color(1.0, 0.30, 0.58, 0.50))
	draw_circle(point, 5.0, Color(1.0, 0.92, 0.98, 0.92))
	draw_line(point + Vector2(-15, 0), point + Vector2(15, 0), Color(1.0, 0.80, 0.95, 0.62), 2.0, true)
	draw_line(point + Vector2(0, -15), point + Vector2(0, 15), Color(1.0, 0.80, 0.95, 0.62), 2.0, true)


func _on_wave_expired(wave) -> void:
	waves.erase(wave)
	player_waves.erase(wave)


func _cleanup_dead_waves() -> void:
	for i in range(waves.size() - 1, -1, -1):
		if not is_instance_valid(waves[i]):
			waves.remove_at(i)
	for i in range(player_waves.size() - 1, -1, -1):
		if not is_instance_valid(player_waves[i]):
			player_waves.remove_at(i)
