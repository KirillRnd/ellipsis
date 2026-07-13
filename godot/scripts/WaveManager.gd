class_name WaveManager
extends Node2D

signal danger_changed(danger_value: int)

const WAVE_SCENE = preload("res://scenes/Wave.tscn")
const ARENA_RECT = Rect2(Vector2(80, 60), Vector2(1120, 600))
const PLAYER_WAVE_DAMAGE = 1
const PLAYER_NODE_DAMAGE = 3
const ENEMY_NODE_DAMAGE = 3
const NODE_HIT_RADIUS = 26.0
const BOOST_NODE_RADIUS = 28.0
const EMITTER_HITBOX_RADIUS := WaveEmitter.HITBOX_RADIUS
const MIN_ERASE_SEGMENT = 72.0
const ERASE_ARC_WIDTH = 0.30
const SAFE_GAP_CLEAR_WIDTH := 48.0
const SAFE_GAP_CORE_WIDTH := 20.0
const SAFE_GAP_JAMB_DEPTH := 28.0
const SAFE_GAP_BOUNDARY_GLOW_WIDTH := Wave.SHARED_CREST_WIDTH
const SAFE_GAP_BOUNDARY_LINE_WIDTH := Wave.SHARED_CREST_WIDTH * 0.425
const SAFE_GAP_BOUNDARY_CORE_WIDTH := 1.0
const SAFE_GAP_LINE_HALF_LENGTH := 56.0
const SAFE_GAP_ARC_MERGE_TOLERANCE := 0.015
const SAFE_GAP_LINE_MERGE_TOLERANCE := 3.0

var player
var emitters: Array = []
var waves: Array = []
var player_waves: Array = []
var _last_danger_value = 0
var _boost_damage_marks = {}


func spawn_wave(wave_owner: String, wave_kind: String, origin: Vector2, config: Dictionary = {}):
	var wave = WAVE_SCENE.instantiate()
	var host = get_parent()
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


func clear_all_waves() -> void:
	for wave in waves:
		if is_instance_valid(wave):
			wave.queue_free()
	waves.clear()
	player_waves.clear()
	_boost_damage_marks.clear()
	_last_danger_value = 0
	queue_redraw()


func _process(_delta: float) -> void:
	_cleanup_dead_waves()
	_damage_emitters()
	if is_instance_valid(player):
		var danger = get_point_danger(player.global_position)
		if danger != _last_danger_value:
			_last_danger_value = danger
			danger_changed.emit(danger)
		if danger > 0:
			player.take_hit(danger)
	queue_redraw()


func get_point_danger(global_point: Vector2) -> int:
	var enemy_waves = _enemy_crests_at(global_point, 7.0)
	if enemy_waves.is_empty():
		return 0

	var safe_gaps := _build_safe_gaps()
	for enemy_wave in enemy_waves:
		if _point_inside_safe_gap(global_point, enemy_wave, safe_gaps):
			return -1

	if _point_on_enemy_interference_node(global_point):
		return ENEMY_NODE_DAMAGE

	return 1


func _enemy_crests_at(global_point: Vector2, margin: float) -> Array:
	var result = []
	for wave in waves:
		if not is_instance_valid(wave):
			continue
		if wave.wave_owner == "enemy" and wave.is_crest_at(global_point, margin):
			result.append(wave)
	return result


func _point_on_enemy_interference_node(global_point: Vector2) -> bool:
	var enemies = _enemy_waves()
	for a_index in range(enemies.size()):
		var a = enemies[a_index]
		for b_index in range(a_index + 1, enemies.size()):
			var b = enemies[b_index]
			for point in _front_intersections(a, b):
				if ARENA_RECT.has_point(point) and point.distance_to(global_point) <= NODE_HIT_RADIUS:
					return true
	return false


func _damage_emitters() -> void:
	for emitter in emitters:
		if not is_instance_valid(emitter) or not emitter.can_take_damage():
			continue
		var emitter_id = emitter.get_instance_id()
		if emitter.can_take_direct_damage():
			for wave in player_waves:
				if not is_instance_valid(wave):
					continue
				if not wave.can_damage_emitters:
					continue
				if wave.damaged_emitters.has(emitter_id):
					continue
				if wave.is_crest_at(emitter.global_position, EMITTER_HITBOX_RADIUS):
					wave.damaged_emitters[emitter_id] = true
					emitter.take_damage(PLAYER_WAVE_DAMAGE)

		if emitter.can_take_boost_damage():
			for pair in _player_intersection_pairs():
				var key = "%s:%s:%s" % [pair[0].get_instance_id(), pair[1].get_instance_id(), emitter_id]
				if _boost_damage_marks.has(key):
					continue
				for point in _front_intersections(pair[0], pair[1]):
					if point.distance_to(emitter.global_position) <= BOOST_NODE_RADIUS:
						_boost_damage_marks[key] = true
						emitter.take_damage(PLAYER_NODE_DAMAGE)
						break


func _draw() -> void:
	_draw_player_erasure()
	_draw_enemy_interference_nodes()
	_draw_player_interference_nodes()


func _draw_player_erasure() -> void:
	for gap in _build_safe_gaps():
		if gap.get("shape", "") == "line":
			_draw_merged_line_safe_gap(gap)
		else:
			_draw_merged_arc_safe_gap(gap)


func _draw_enemy_interference_nodes() -> void:
	var enemies = _enemy_waves()
	for a_index in range(enemies.size()):
		var a = enemies[a_index]
		if not is_instance_valid(a):
			continue
		for b_index in range(a_index + 1, enemies.size()):
			var b = enemies[b_index]
			if not is_instance_valid(b):
				continue
			for point in _front_intersections(a, b):
				if ARENA_RECT.has_point(point):
					_draw_enemy_danger_node(point)


func _draw_player_interference_nodes() -> void:
	for pair in _player_intersection_pairs():
		for point in _front_intersections(pair[0], pair[1]):
			if ARENA_RECT.has_point(point):
				_draw_player_boost_node(point)


func _player_intersection_pairs() -> Array:
	var result = []
	for a_index in range(player_waves.size()):
		var a = player_waves[a_index]
		if not is_instance_valid(a) or not a.can_create_boost:
			continue
		for b_index in range(a_index + 1, player_waves.size()):
			var b = player_waves[b_index]
			if is_instance_valid(b) and b.can_create_boost:
				result.append([a, b])
	return result


func _enemy_waves() -> Array:
	var enemies = []
	for wave in waves:
		if is_instance_valid(wave) and wave.wave_owner == "enemy":
			enemies.append(wave)
	return enemies


func _build_safe_gaps() -> Array:
	var raw_by_enemy := {}
	for enemy_wave in _enemy_waves():
		raw_by_enemy[enemy_wave.get_instance_id()] = {
			"enemy_wave": enemy_wave,
			"circle": [],
			"line": [],
		}

	for enemy_wave in _enemy_waves():
		var enemy_id = enemy_wave.get_instance_id()
		for counter_wave in player_waves:
			if not is_instance_valid(counter_wave):
				continue
			for point in _front_intersections(enemy_wave, counter_wave):
				if not ARENA_RECT.has_point(point):
					continue
				if enemy_wave.wave_shape == "line":
					_append_line_safe_gap(raw_by_enemy[enemy_id]["line"], enemy_wave, counter_wave, point)
				else:
					_append_arc_safe_gap(raw_by_enemy[enemy_id]["circle"], enemy_wave, counter_wave, point)

	var result := []
	for enemy_id in raw_by_enemy.keys():
		var entry = raw_by_enemy[enemy_id]
		result.append_array(_merge_safe_gap_intervals(entry["circle"], SAFE_GAP_ARC_MERGE_TOLERANCE, true))
		result.append_array(_merge_safe_gap_intervals(entry["line"], SAFE_GAP_LINE_MERGE_TOLERANCE, false))
	return result


func _append_arc_safe_gap(gaps: Array, enemy_wave, counter_wave, point: Vector2) -> void:
	var radius: float = enemy_wave.radius
	if radius * ERASE_ARC_WIDTH * 2.0 < MIN_ERASE_SEGMENT:
		return

	var angle := _normalize_angle_positive((point - enemy_wave.global_position).angle())
	var start := angle - ERASE_ARC_WIDTH
	var end := angle + ERASE_ARC_WIDTH
	_append_normalized_arc_interval(gaps, enemy_wave, counter_wave, start, end)


func _append_normalized_arc_interval(gaps: Array, enemy_wave, counter_wave, start: float, end: float) -> void:
	if start < 0.0:
		gaps.append(_make_safe_gap(enemy_wave, "circle", start + TAU, TAU, counter_wave, counter_wave))
		gaps.append(_make_safe_gap(enemy_wave, "circle", 0.0, end, counter_wave, counter_wave))
	elif end > TAU:
		gaps.append(_make_safe_gap(enemy_wave, "circle", start, TAU, counter_wave, counter_wave))
		gaps.append(_make_safe_gap(enemy_wave, "circle", 0.0, end - TAU, counter_wave, counter_wave))
	else:
		gaps.append(_make_safe_gap(enemy_wave, "circle", start, end, counter_wave, counter_wave))


func _append_line_safe_gap(gaps: Array, enemy_wave, counter_wave, point: Vector2) -> void:
	var tangent = Vector2(-enemy_wave.line_direction.y, enemy_wave.line_direction.x)
	var base = enemy_wave.global_position + enemy_wave.line_direction * enemy_wave.radius
	var side = (point - base).dot(tangent)
	var edge_room = enemy_wave.line_half_length - absf(side)
	if edge_room < MIN_ERASE_SEGMENT * 0.5:
		return

	var start = clampf(side - SAFE_GAP_LINE_HALF_LENGTH, -enemy_wave.line_half_length, enemy_wave.line_half_length)
	var end = clampf(side + SAFE_GAP_LINE_HALF_LENGTH, -enemy_wave.line_half_length, enemy_wave.line_half_length)
	gaps.append(_make_safe_gap(enemy_wave, "line", start, end, counter_wave, counter_wave))


func _make_safe_gap(enemy_wave, shape: String, start: float, end: float, start_wave, end_wave) -> Dictionary:
	return {
		"enemy_wave": enemy_wave,
		"shape": shape,
		"start": start,
		"end": end,
		"start_wave": start_wave,
		"end_wave": end_wave,
	}


func _merge_safe_gap_intervals(gaps: Array, tolerance: float, wraps: bool) -> Array:
	if gaps.is_empty():
		return []

	gaps.sort_custom(func(a, b): return a["start"] < b["start"])
	var merged := []
	for gap in gaps:
		if merged.is_empty():
			merged.append(gap.duplicate())
			continue

		var current = merged[merged.size() - 1]
		if gap["start"] <= current["end"] + tolerance:
			if gap["end"] > current["end"]:
				current["end"] = gap["end"]
				current["end_wave"] = gap["end_wave"]
		else:
			merged.append(gap.duplicate())

	if wraps and merged.size() > 1:
		var first = merged[0]
		var last = merged[merged.size() - 1]
		if first["start"] <= tolerance and last["end"] >= TAU - tolerance:
			last["end"] = first["end"] + TAU
			last["end_wave"] = first["end_wave"]
			merged.remove_at(0)

	return merged


func _point_inside_safe_gap(global_point: Vector2, enemy_wave, safe_gaps: Array) -> bool:
	for gap in safe_gaps:
		if not is_instance_valid(gap["enemy_wave"]) or gap["enemy_wave"] != enemy_wave:
			continue
		if gap["shape"] == "line":
			if _point_inside_line_safe_gap(global_point, gap):
				return true
		elif _point_inside_arc_safe_gap(global_point, gap):
			return true
	return false


func _point_inside_arc_safe_gap(global_point: Vector2, gap: Dictionary) -> bool:
	var enemy_wave = gap["enemy_wave"]
	var angle := _normalize_angle_positive((global_point - enemy_wave.global_position).angle())
	var start: float = gap["start"]
	var end: float = gap["end"]
	if end > TAU and angle < start:
		angle += TAU
	return angle >= start and angle <= end


func _point_inside_line_safe_gap(global_point: Vector2, gap: Dictionary) -> bool:
	var enemy_wave = gap["enemy_wave"]
	var tangent = Vector2(-enemy_wave.line_direction.y, enemy_wave.line_direction.x)
	var base = enemy_wave.global_position + enemy_wave.line_direction * enemy_wave.radius
	var side = (global_point - base).dot(tangent)
	return side >= gap["start"] and side <= gap["end"]


func _normalize_angle_positive(angle: float) -> float:
	return fposmod(angle, TAU)


func _front_intersections(a, b) -> Array[Vector2]:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return []
	if a.get_crest_radii().is_empty() or b.get_crest_radii().is_empty():
		return []

	var ar: float = a.get_crest_radii()[0]
	var br: float = b.get_crest_radii()[0]
	if a.wave_shape == "circle" and b.wave_shape == "circle":
		return _circle_intersections(a.global_position, ar, b.global_position, br)
	if a.wave_shape == "line" and b.wave_shape == "circle":
		return _line_circle_intersections(a, ar, b, br)
	if a.wave_shape == "circle" and b.wave_shape == "line":
		return _line_circle_intersections(b, br, a, ar)
	return _line_line_intersections(a, ar, b, br)


func _circles_can_intersect(a: Vector2, ar: float, b: Vector2, br: float) -> bool:
	var d = a.distance_to(b)
	return d > 0.01 and d <= ar + br and d >= absf(ar - br)


func _circle_intersections(a: Vector2, ar: float, b: Vector2, br: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not _circles_can_intersect(a, ar, b, br):
		return result
	var delta = b - a
	var d = delta.length()
	if d <= 0.01:
		return result

	var along = (ar * ar - br * br + d * d) / (2.0 * d)
	var height_sq = ar * ar - along * along
	if height_sq < 0.0:
		return result

	var dir = delta / d
	var base = a + dir * along
	var normal = Vector2(-dir.y, dir.x)
	var height = sqrt(height_sq)
	result.append(base + normal * height)
	if height > 0.5:
		result.append(base - normal * height)
	return result


func _line_circle_intersections(line_wave, line_radius: float, circle_wave, circle_radius: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var tangent = Vector2(-line_wave.line_direction.y, line_wave.line_direction.x)
	var base = line_wave.global_position + line_wave.line_direction * line_radius
	var offset = base - circle_wave.global_position
	var side_center = -offset.dot(tangent)
	var dist_sq = offset.length_squared() - offset.dot(tangent) * offset.dot(tangent)
	var radius_sq = circle_radius * circle_radius
	if dist_sq > radius_sq:
		return result
	var half_span = sqrt(maxf(0.0, radius_sq - dist_sq))
	for side in [side_center - half_span, side_center + half_span]:
		if absf(side) <= line_wave.line_half_length:
			result.append(base + tangent * side)
	return result


func _line_line_intersections(a, ar: float, b, br: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var a_tangent = Vector2(-a.line_direction.y, a.line_direction.x)
	var b_tangent = Vector2(-b.line_direction.y, b.line_direction.x)
	var a_base = a.global_position + a.line_direction * ar
	var b_base = b.global_position + b.line_direction * br
	var denom = a_tangent.cross(b_tangent)
	if absf(denom) < 0.001:
		return result
	var delta = b_base - a_base
	var a_side = delta.cross(b_tangent) / denom
	var b_side = delta.cross(a_tangent) / denom
	if absf(a_side) <= a.line_half_length and absf(b_side) <= b.line_half_length:
		result.append(a_base + a_tangent * a_side)
	return result


func _draw_merged_arc_safe_gap(gap: Dictionary) -> void:
	var enemy_wave = gap["enemy_wave"]
	if not is_instance_valid(enemy_wave):
		return
	var center: Vector2 = enemy_wave.global_position
	var radius: float = enemy_wave.radius
	var start_angle: float = gap["start"]
	var end_angle: float = gap["end"]
	var point_count = maxi(8, int(ceil(absf(end_angle - start_angle) / TAU * 160.0)))
	var clear := Color(0.42, 0.41, 0.39, 0.96)
	var calm := _safe_gap_body_color(gap)
	calm.a = 0.14
	draw_arc(center, radius, start_angle, end_angle, point_count, clear, SAFE_GAP_CLEAR_WIDTH, true)
	draw_arc(center, radius, start_angle, end_angle, point_count, calm, SAFE_GAP_CORE_WIDTH, true)

	_draw_arc_safe_gap_jamb(center, radius, start_angle, 1.0, enemy_wave, gap["start_wave"])
	_draw_arc_safe_gap_jamb(center, radius, end_angle, -1.0, enemy_wave, gap["end_wave"])


func _draw_merged_line_safe_gap(gap: Dictionary) -> void:
	var enemy_wave = gap["enemy_wave"]
	if not is_instance_valid(enemy_wave):
		return
	var tangent = Vector2(-enemy_wave.line_direction.y, enemy_wave.line_direction.x)
	var base = enemy_wave.global_position + enemy_wave.line_direction * enemy_wave.radius
	var start = base + tangent * float(gap["start"])
	var end = base + tangent * float(gap["end"])
	var clear := Color(0.42, 0.41, 0.39, 0.96)
	var calm := _safe_gap_body_color(gap)
	calm.a = 0.14
	draw_line(start, end, clear, SAFE_GAP_CLEAR_WIDTH, true)
	draw_line(start, end, calm, SAFE_GAP_CORE_WIDTH, true)
	_draw_line_safe_gap_jamb(start, tangent, 1.0, enemy_wave, gap["start_wave"])
	_draw_line_safe_gap_jamb(end, tangent, -1.0, enemy_wave, gap["end_wave"])


func _draw_arc_safe_gap_jamb(center: Vector2, radius: float, edge_angle: float, inner_sign: float, enemy_wave, counter_wave) -> void:
	var direction := Vector2.from_angle(edge_angle)
	var tangent := Vector2(-direction.y, direction.x)
	var jamb_center := center + direction * radius
	_draw_safe_gap_jamb(jamb_center, direction, tangent * inner_sign, enemy_wave, counter_wave)


func _draw_line_safe_gap_jamb(center: Vector2, tangent: Vector2, inner_sign: float, enemy_wave, counter_wave) -> void:
	_draw_safe_gap_jamb(center, enemy_wave.line_direction, tangent * inner_sign, enemy_wave, counter_wave)


func _draw_safe_gap_jamb(center: Vector2, direction: Vector2, inner_offset_direction: Vector2, enemy_wave, counter_wave) -> void:
	var from := center - direction * SAFE_GAP_JAMB_DEPTH
	var to := center + direction * SAFE_GAP_JAMB_DEPTH
	var normal := inner_offset_direction.normalized()
	_draw_safe_gap_boundary_half(from, to, -normal, enemy_wave.color, _safe_gap_wave_alpha(enemy_wave))
	_draw_safe_gap_boundary_half(from, to, normal, _safe_gap_suppress_color(counter_wave), _safe_gap_wave_alpha(counter_wave))


func _draw_safe_gap_boundary_half(from: Vector2, to: Vector2, side: Vector2, base_color: Color, local_alpha: float) -> void:
	var glow_color := base_color
	glow_color.a = 0.10 * local_alpha
	var line_color := base_color
	line_color.a = 0.78 * local_alpha
	var core_color := base_color.lerp(Color.WHITE, 0.68)
	core_color.a = 0.42 * local_alpha
	_draw_safe_gap_boundary_layer(from, to, side, glow_color, SAFE_GAP_BOUNDARY_GLOW_WIDTH)
	_draw_safe_gap_boundary_layer(from, to, side, line_color, SAFE_GAP_BOUNDARY_LINE_WIDTH)
	_draw_safe_gap_boundary_layer(from, to, side, core_color, SAFE_GAP_BOUNDARY_CORE_WIDTH)


func _draw_safe_gap_boundary_layer(from: Vector2, to: Vector2, side: Vector2, color: Color, width: float) -> void:
	var offset := side * width * 0.5
	draw_line(from + offset, to + offset, color, width, true)


func _safe_gap_wave_alpha(wave) -> float:
	if not is_instance_valid(wave):
		return 1.0
	var fade := clampf(1.0 - wave.age / wave.lifetime, 0.0, 1.0)
	return fade * clampf(wave.radius / 90.0, 0.35, 1.0)


func _safe_gap_suppress_color(counter_wave) -> Color:
	if is_instance_valid(counter_wave) and counter_wave.wave_kind == "blue":
		return Color(0.26, 0.76, 1.0)
	return Color(0.62, 0.36, 1.0)


func _safe_gap_body_color(gap: Dictionary) -> Color:
	var start_color := _safe_gap_suppress_color(gap["start_wave"])
	var end_color := _safe_gap_suppress_color(gap["end_wave"])
	if start_color == end_color:
		return start_color
	return start_color.lerp(end_color, 0.5)


func _draw_enemy_danger_node(point: Vector2) -> void:
	draw_circle(point, 30.0, Color(1.0, 0.03, 0.12, 0.22))
	draw_circle(point, 15.0, Color(1.0, 0.08, 0.18, 0.62))
	draw_circle(point, 6.0, Color(1.0, 0.90, 0.92, 0.95))
	draw_line(point + Vector2(-17, 0), point + Vector2(17, 0), Color(1.0, 0.68, 0.72, 0.72), 2.0, true)
	draw_line(point + Vector2(0, -17), point + Vector2(0, 17), Color(1.0, 0.68, 0.72, 0.72), 2.0, true)


func _draw_player_boost_node(point: Vector2) -> void:
	draw_circle(point, BOOST_NODE_RADIUS, Color(0.10, 0.45, 1.0, 0.22))
	draw_circle(point, 14.0, Color(0.24, 0.72, 1.0, 0.58))
	draw_circle(point, 5.0, Color(0.88, 0.98, 1.0, 0.95))
	draw_line(point + Vector2(-16, 0), point + Vector2(16, 0), Color(0.72, 0.94, 1.0, 0.72), 2.0, true)
	draw_line(point + Vector2(0, -16), point + Vector2(0, 16), Color(0.72, 0.94, 1.0, 0.72), 2.0, true)


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
