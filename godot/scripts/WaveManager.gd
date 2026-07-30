class_name WaveManager
extends Node2D

signal danger_changed(danger_value: int)

const WAVE_SCENE = preload("res://scenes/Wave.tscn")
const WAVE_AUDIO_EVENTS := {
	"resonator": &"wave.launch.purple",
	"blue": &"wave.launch.blue",
	"red": &"wave.launch.red",
}
const ARENA_RECT = Rect2(Vector2(80, 60), Vector2(1120, 600))
const PLAYER_WAVE_DAMAGE = 1
const BLUE_VIOLET_RESONANCE_DAMAGE := 6
const VIOLET_VIOLET_RESONANCE_DAMAGE := 7
const ENEMY_NODE_DAMAGE = 3
const NODE_HIT_RADIUS = 26.0
const RESONANCE_NODE_RADIUS = 28.0
const EMITTER_HITBOX_RADIUS := WaveEmitter.HITBOX_RADIUS
const MIN_ERASE_SEGMENT = 72.0
const ERASE_ARC_WIDTH = 0.30
const SAFE_GAP_CLEAR_WIDTH := 32.0
const SAFE_GAP_CORE_WIDTH := 13.333333
const SAFE_GAP_JAMB_DEPTH := 28.0
const SAFE_GAP_BOUNDARY_GLOW_WIDTH := Wave.SHARED_CREST_WIDTH
const SAFE_GAP_BOUNDARY_LINE_WIDTH := Wave.SHARED_CREST_WIDTH * 0.425
const SAFE_GAP_BOUNDARY_CORE_WIDTH := 1.0
const SAFE_GAP_LINE_HALF_LENGTH := 56.0
const SAFE_GAP_ARC_MERGE_TOLERANCE := 0.015
const SAFE_GAP_LINE_MERGE_TOLERANCE := 3.0
const CROSSBAR_SAFE_GAP_INNER_COLOR := Color(0.56, 0.57, 0.58)

var player
var driven_crossbar: SteelCrossbarDriven
var boss_target
var emitters: Array = []
var waves: Array = []
var player_waves: Array = []
var _last_danger_value = 0
var _resonance_damage_marks = {}
@onready var _audio: AudioRuntime = get_node_or_null("/root/Audio") as AudioRuntime


func spawn_wave(wave_owner: String, wave_kind: String, origin: Vector2, config: Dictionary = {}):
	var wave = WAVE_SCENE.instantiate()
	var host = get_parent()
	if host == null:
		host = self
	host.add_child(wave)
	if host != self:
		host.move_child(wave, get_index())

	wave.setup(wave_owner, wave_kind, origin, config)
	var audio_event: StringName = WAVE_AUDIO_EVENTS.get(wave_kind, &"")
	if _audio != null and not audio_event.is_empty():
		_audio.play_2d(audio_event, origin)
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
	_resonance_damage_marks.clear()
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


func set_driven_crossbar(crossbar: SteelCrossbarDriven) -> void:
	driven_crossbar = crossbar


func set_boss_target(target) -> void:
	boss_target = target


func get_point_danger(global_point: Vector2) -> int:
	var enemy_waves = _enemy_crests_at(global_point, 7.0)
	if enemy_waves.is_empty():
		return 0

	var safe_gaps := _build_safe_gaps()
	var active_enemy_waves := []
	for enemy_wave in enemy_waves:
		if _front_exists_at(global_point, enemy_wave, safe_gaps):
			active_enemy_waves.append(enemy_wave)
	if active_enemy_waves.is_empty():
		return -1

	if _point_on_enemy_interference_node(global_point, safe_gaps):
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


func _point_on_enemy_interference_node(global_point: Vector2, safe_gaps: Array) -> bool:
	for point in _enemy_interference_points(safe_gaps):
		if point.distance_to(global_point) <= NODE_HIT_RADIUS:
			return true
	return false


func _damage_emitters() -> void:
	var safe_gaps := _build_safe_gaps()
	var targets := emitters.duplicate()
	if is_instance_valid(boss_target):
		targets.append(boss_target)
	for target in targets:
		if not is_instance_valid(target) or not target.can_take_damage():
			continue
		var target_id = target.get_instance_id()
		var hitbox_radius := EMITTER_HITBOX_RADIUS
		if target.has_method("get_hitbox_radius"):
			hitbox_radius = target.get_hitbox_radius()
		if target.can_take_direct_damage():
			for wave in player_waves:
				if not is_instance_valid(wave):
					continue
				if not wave.can_damage_emitters:
					continue
				if wave.damaged_emitters.has(target_id):
					continue
				if wave.is_crest_at(target.global_position, hitbox_radius):
					if _point_inside_safe_gap(target.global_position, wave, safe_gaps):
						continue
					wave.damaged_emitters[target_id] = true
					target.take_damage(PLAYER_WAVE_DAMAGE)

		if target.can_take_resonance_damage():
			for resonance_node in _player_resonance_nodes(safe_gaps):
				var first = resonance_node["first"]
				var second = resonance_node["second"]
				var resonance_type: String = resonance_node["type"]
				var key = "%s:%s:%s" % [first.get_instance_id(), second.get_instance_id(), target_id]
				if _resonance_damage_marks.has(key):
					continue
				var point: Vector2 = resonance_node["point"]
				if point.distance_to(target.global_position) <= RESONANCE_NODE_RADIUS:
					_resonance_damage_marks[key] = true
					target.take_damage(_resonance_damage(resonance_type))


func _draw() -> void:
	var safe_gaps := _build_safe_gaps()
	_draw_player_erasure(safe_gaps)
	_draw_enemy_interference_nodes(safe_gaps)
	_draw_player_interference_nodes(safe_gaps)


func _draw_player_erasure(safe_gaps: Array) -> void:
	for gap in safe_gaps:
		if gap.get("shape", "") == "line":
			_draw_merged_line_safe_gap(gap)
		else:
			_draw_merged_arc_safe_gap(gap)


func _draw_enemy_interference_nodes(safe_gaps: Array) -> void:
	for point in _enemy_interference_points(safe_gaps):
		_draw_enemy_danger_node(point)


func _enemy_interference_points(safe_gaps: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var enemies = _enemy_waves()
	for a_index in range(enemies.size()):
		var a = enemies[a_index]
		if not is_instance_valid(a):
			continue
		for b_index in range(a_index + 1, enemies.size()):
			var b = enemies[b_index]
			if not is_instance_valid(b):
				continue
			for point in _active_front_intersections(a, b, safe_gaps):
				if ARENA_RECT.has_point(point):
					result.append(point)
	return result


func _draw_player_interference_nodes(safe_gaps: Array) -> void:
	for resonance_node in _player_resonance_nodes(safe_gaps):
		_draw_player_resonance_node(resonance_node["point"], resonance_node["type"])


func _player_resonance_nodes(safe_gaps: Array) -> Array:
	var result := []
	for pair in _player_resonance_pairs():
		var first = pair["first"]
		var second = pair["second"]
		for point in _active_front_intersections(first, second, safe_gaps):
			if ARENA_RECT.has_point(point):
				result.append({
					"point": point,
					"first": first,
					"second": second,
					"type": pair["type"],
				})
	return result


func _player_resonance_pairs() -> Array:
	var result = []
	for a_index in range(player_waves.size()):
		var a = player_waves[a_index]
		if not is_instance_valid(a) or not a.can_create_resonance:
			continue
		for b_index in range(a_index + 1, player_waves.size()):
			var b = player_waves[b_index]
			if not is_instance_valid(b) or not b.can_create_resonance:
				continue
			var resonance_type := _resonance_type(a, b)
			if not resonance_type.is_empty():
				result.append({
					"first": a,
					"second": b,
					"type": resonance_type,
				})
	return result


func _resonance_type(first, second) -> String:
	var kinds := [first.wave_kind, second.wave_kind]
	if "blue" in kinds and "resonator" in kinds:
		return "blue_violet"
	if first.wave_kind == "resonator" and second.wave_kind == "resonator":
		return "violet_violet"
	return ""


func _resonance_damage(resonance_type: String) -> int:
	if resonance_type == "violet_violet":
		return VIOLET_VIOLET_RESONANCE_DAMAGE
	return BLUE_VIOLET_RESONANCE_DAMAGE


func _enemy_waves() -> Array:
	var enemies = []
	for wave in waves:
		if is_instance_valid(wave) and wave.wave_owner == "enemy":
			enemies.append(wave)
	return enemies


func _build_safe_gaps() -> Array:
	var raw_by_wave := {}
	for enemy_wave in _enemy_waves():
		for counter_wave in player_waves:
			if not is_instance_valid(counter_wave):
				continue
			for point in _front_intersections(enemy_wave, counter_wave):
				if not ARENA_RECT.has_point(point):
					continue
				_append_safe_gap(raw_by_wave, enemy_wave, counter_wave, point)
				_append_safe_gap(raw_by_wave, counter_wave, enemy_wave, point)

	_append_crossbar_safe_gaps(raw_by_wave)

	var result := []
	for wave_id in raw_by_wave.keys():
		var entry = raw_by_wave[wave_id]
		result.append_array(_merge_safe_gap_intervals(entry["circle"], SAFE_GAP_ARC_MERGE_TOLERANCE, true))
		result.append_array(_merge_safe_gap_intervals(entry["line"], SAFE_GAP_LINE_MERGE_TOLERANCE, false))
	return result


func _append_crossbar_safe_gaps(raw_by_wave: Dictionary) -> void:
	if not is_instance_valid(driven_crossbar):
		driven_crossbar = null
		return

	for wave in waves:
		if not driven_crossbar.can_affect_wave(wave):
			continue
		if not wave.is_crest_at(driven_crossbar.global_position, SteelCrossbarDriven.CONTACT_RADIUS):
			continue
		driven_crossbar.mark_wave_processed(wave)
		_append_crossbar_safe_gap(raw_by_wave, wave, driven_crossbar)


func _append_crossbar_safe_gap(
	raw_by_wave: Dictionary,
	wave,
	crossbar: SteelCrossbarDriven,
) -> void:
	var wave_id = wave.get_instance_id()
	if not raw_by_wave.has(wave_id):
		raw_by_wave[wave_id] = {
			"protected_wave": wave,
			"circle": [],
			"line": [],
		}
	if wave.wave_shape == "line":
		_append_crossbar_line_safe_gap(raw_by_wave[wave_id]["line"], wave, crossbar)
	else:
		_append_crossbar_arc_safe_gap(raw_by_wave[wave_id]["circle"], wave, crossbar)


func _append_crossbar_arc_safe_gap(
	gaps: Array,
	wave,
	crossbar: SteelCrossbarDriven,
) -> void:
	var from_center: Vector2 = crossbar.global_position - wave.global_position
	if from_center.length_squared() <= 0.0 or wave.radius <= 0.0:
		return
	var direction := from_center.normalized()
	var tangent := Vector2(-direction.y, direction.x)
	var width := crossbar.get_gap_width(tangent)
	var half_angle := minf(width * 0.5 / wave.radius, PI)
	var center_angle := _normalize_angle_positive(direction.angle())
	var start := center_angle - half_angle
	var end := center_angle + half_angle
	if start < 0.0:
		gaps.append(_make_crossbar_safe_gap(wave, "circle", start + TAU, TAU))
		gaps.append(_make_crossbar_safe_gap(wave, "circle", 0.0, end))
	elif end > TAU:
		gaps.append(_make_crossbar_safe_gap(wave, "circle", start, TAU))
		gaps.append(_make_crossbar_safe_gap(wave, "circle", 0.0, end - TAU))
	else:
		gaps.append(_make_crossbar_safe_gap(wave, "circle", start, end))


func _append_crossbar_line_safe_gap(
	gaps: Array,
	wave,
	crossbar: SteelCrossbarDriven,
) -> void:
	var tangent := Vector2(-wave.line_direction.y, wave.line_direction.x)
	var base: Vector2 = wave.global_position + wave.line_direction * wave.radius
	var side := (crossbar.global_position - base).dot(tangent)
	var half_width := crossbar.get_gap_width(tangent) * 0.5
	var start := clampf(side - half_width, -wave.line_half_length, wave.line_half_length)
	var end := clampf(side + half_width, -wave.line_half_length, wave.line_half_length)
	gaps.append(_make_crossbar_safe_gap(wave, "line", start, end))


func _make_crossbar_safe_gap(wave, shape: String, start: float, end: float) -> Dictionary:
	return _make_safe_gap(
		wave,
		shape,
		start,
		end,
		null,
		null,
		CROSSBAR_SAFE_GAP_INNER_COLOR,
		CROSSBAR_SAFE_GAP_INNER_COLOR,
	)


func _append_safe_gap(raw_by_wave: Dictionary, protected_wave, suppress_wave, point: Vector2) -> void:
	var wave_id = protected_wave.get_instance_id()
	if not raw_by_wave.has(wave_id):
		raw_by_wave[wave_id] = {
			"protected_wave": protected_wave,
			"circle": [],
			"line": [],
		}

	if protected_wave.wave_shape == "line":
		_append_line_safe_gap(raw_by_wave[wave_id]["line"], protected_wave, suppress_wave, point)
	else:
		_append_arc_safe_gap(raw_by_wave[wave_id]["circle"], protected_wave, suppress_wave, point)


func _append_arc_safe_gap(gaps: Array, protected_wave, suppress_wave, point: Vector2) -> void:
	var radius: float = protected_wave.radius
	if radius * ERASE_ARC_WIDTH * 2.0 < MIN_ERASE_SEGMENT:
		return

	var angle := _normalize_angle_positive((point - protected_wave.global_position).angle())
	var start := angle - ERASE_ARC_WIDTH
	var end := angle + ERASE_ARC_WIDTH
	_append_normalized_arc_interval(gaps, protected_wave, suppress_wave, start, end)


func _append_normalized_arc_interval(gaps: Array, protected_wave, suppress_wave, start: float, end: float) -> void:
	if start < 0.0:
		gaps.append(_make_safe_gap(protected_wave, "circle", start + TAU, TAU, suppress_wave, suppress_wave))
		gaps.append(_make_safe_gap(protected_wave, "circle", 0.0, end, suppress_wave, suppress_wave))
	elif end > TAU:
		gaps.append(_make_safe_gap(protected_wave, "circle", start, TAU, suppress_wave, suppress_wave))
		gaps.append(_make_safe_gap(protected_wave, "circle", 0.0, end - TAU, suppress_wave, suppress_wave))
	else:
		gaps.append(_make_safe_gap(protected_wave, "circle", start, end, suppress_wave, suppress_wave))


func _append_line_safe_gap(gaps: Array, protected_wave, suppress_wave, point: Vector2) -> void:
	var tangent = Vector2(-protected_wave.line_direction.y, protected_wave.line_direction.x)
	var base = protected_wave.global_position + protected_wave.line_direction * protected_wave.radius
	var side = (point - base).dot(tangent)
	var edge_room = protected_wave.line_half_length - absf(side)
	if edge_room < MIN_ERASE_SEGMENT * 0.5:
		return

	var start = clampf(side - SAFE_GAP_LINE_HALF_LENGTH, -protected_wave.line_half_length, protected_wave.line_half_length)
	var end = clampf(side + SAFE_GAP_LINE_HALF_LENGTH, -protected_wave.line_half_length, protected_wave.line_half_length)
	gaps.append(_make_safe_gap(protected_wave, "line", start, end, suppress_wave, suppress_wave))


func _make_safe_gap(
	protected_wave,
	shape: String,
	start: float,
	end: float,
	start_suppress_wave,
	end_suppress_wave,
	start_inner_color = null,
	end_inner_color = null,
) -> Dictionary:
	return {
		"protected_wave": protected_wave,
		"shape": shape,
		"start": start,
		"end": end,
		"start_suppress_wave": start_suppress_wave,
		"end_suppress_wave": end_suppress_wave,
		"start_inner_color": start_inner_color,
		"end_inner_color": end_inner_color,
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
				current["end_suppress_wave"] = gap["end_suppress_wave"]
				current["end_inner_color"] = gap["end_inner_color"]
		else:
			merged.append(gap.duplicate())

	if wraps and merged.size() > 1:
		var first = merged[0]
		var last = merged[merged.size() - 1]
		if first["start"] <= tolerance and last["end"] >= TAU - tolerance:
			last["end"] = first["end"] + TAU
			last["end_suppress_wave"] = first["end_suppress_wave"]
			last["end_inner_color"] = first["end_inner_color"]
			merged.remove_at(0)

	return merged


func _point_inside_safe_gap(global_point: Vector2, protected_wave, safe_gaps: Array) -> bool:
	for gap in safe_gaps:
		if not is_instance_valid(gap["protected_wave"]) or gap["protected_wave"] != protected_wave:
			continue
		if gap["shape"] == "line":
			if _point_inside_line_safe_gap(global_point, gap):
				return true
		elif _point_inside_arc_safe_gap(global_point, gap):
			return true
	return false


func _front_exists_at(global_point: Vector2, wave, safe_gaps: Array) -> bool:
	return is_instance_valid(wave) and not _point_inside_safe_gap(global_point, wave, safe_gaps)


func _active_front_intersections(first, second, safe_gaps: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in _front_intersections(first, second):
		if not _front_exists_at(point, first, safe_gaps):
			continue
		if not _front_exists_at(point, second, safe_gaps):
			continue
		result.append(point)
	return result


func _point_inside_arc_safe_gap(global_point: Vector2, gap: Dictionary) -> bool:
	var protected_wave = gap["protected_wave"]
	var angle := _normalize_angle_positive((global_point - protected_wave.global_position).angle())
	var start: float = gap["start"]
	var end: float = gap["end"]
	if end > TAU and angle < start:
		angle += TAU
	return angle >= start and angle <= end


func _point_inside_line_safe_gap(global_point: Vector2, gap: Dictionary) -> bool:
	var protected_wave = gap["protected_wave"]
	var tangent = Vector2(-protected_wave.line_direction.y, protected_wave.line_direction.x)
	var base = protected_wave.global_position + protected_wave.line_direction * protected_wave.radius
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
	var protected_wave = gap["protected_wave"]
	if not is_instance_valid(protected_wave):
		return
	var center: Vector2 = protected_wave.global_position
	var radius: float = protected_wave.radius
	var start_angle: float = gap["start"]
	var end_angle: float = gap["end"]
	var point_count = maxi(8, int(ceil(absf(end_angle - start_angle) / TAU * 160.0)))
	var clear := Color(0.91, 0.90, 0.87, 0.88)
	var calm := _safe_gap_body_color(gap)
	calm.a = 0.10
	draw_arc(center, radius, start_angle, end_angle, point_count, clear, SAFE_GAP_CLEAR_WIDTH, true)
	draw_arc(center, radius, start_angle, end_angle, point_count, calm, SAFE_GAP_CORE_WIDTH, true)

	_draw_arc_safe_gap_jamb(center, radius, start_angle, 1.0, protected_wave, _safe_gap_edge_inner_color(gap, true))
	_draw_arc_safe_gap_jamb(center, radius, end_angle, -1.0, protected_wave, _safe_gap_edge_inner_color(gap, false))


func _draw_merged_line_safe_gap(gap: Dictionary) -> void:
	var protected_wave = gap["protected_wave"]
	if not is_instance_valid(protected_wave):
		return
	var tangent = Vector2(-protected_wave.line_direction.y, protected_wave.line_direction.x)
	var base = protected_wave.global_position + protected_wave.line_direction * protected_wave.radius
	var start = base + tangent * float(gap["start"])
	var end = base + tangent * float(gap["end"])
	var clear := Color(0.91, 0.90, 0.87, 0.88)
	var calm := _safe_gap_body_color(gap)
	calm.a = 0.10
	draw_line(start, end, clear, SAFE_GAP_CLEAR_WIDTH, true)
	draw_line(start, end, calm, SAFE_GAP_CORE_WIDTH, true)
	_draw_line_safe_gap_jamb(start, tangent, 1.0, protected_wave, _safe_gap_edge_inner_color(gap, true))
	_draw_line_safe_gap_jamb(end, tangent, -1.0, protected_wave, _safe_gap_edge_inner_color(gap, false))


func _draw_arc_safe_gap_jamb(
	center: Vector2,
	radius: float,
	edge_angle: float,
	inner_sign: float,
	protected_wave,
	inner_color: Color,
) -> void:
	var direction := Vector2.from_angle(edge_angle)
	var tangent := Vector2(-direction.y, direction.x)
	var jamb_center := center + direction * radius
	_draw_safe_gap_jamb(jamb_center, direction, tangent * inner_sign, protected_wave, inner_color)


func _draw_line_safe_gap_jamb(
	center: Vector2,
	tangent: Vector2,
	inner_sign: float,
	protected_wave,
	inner_color: Color,
) -> void:
	_draw_safe_gap_jamb(center, protected_wave.line_direction, tangent * inner_sign, protected_wave, inner_color)


func _draw_safe_gap_jamb(
	center: Vector2,
	direction: Vector2,
	inner_offset_direction: Vector2,
	protected_wave,
	inner_color: Color,
) -> void:
	var from := center - direction * SAFE_GAP_JAMB_DEPTH
	var to := center + direction * SAFE_GAP_JAMB_DEPTH
	var normal := inner_offset_direction.normalized()
	_draw_safe_gap_boundary_half(from, to, -normal, protected_wave.color, _safe_gap_wave_alpha(protected_wave))
	_draw_safe_gap_boundary_half(from, to, normal, inner_color, _safe_gap_wave_alpha(protected_wave))


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


func _safe_gap_suppress_color(suppress_wave) -> Color:
	if not is_instance_valid(suppress_wave):
		return Color(0.62, 0.36, 1.0)
	if suppress_wave.wave_owner == "enemy":
		return suppress_wave.color
	if suppress_wave.wave_kind == "blue":
		return Color(0.26, 0.76, 1.0)
	return Color(0.62, 0.36, 1.0)


func _safe_gap_body_color(gap: Dictionary) -> Color:
	var start_color := _safe_gap_edge_inner_color(gap, true)
	var end_color := _safe_gap_edge_inner_color(gap, false)
	if start_color == end_color:
		return start_color
	return start_color.lerp(end_color, 0.5)


func _safe_gap_edge_inner_color(gap: Dictionary, start_edge: bool) -> Color:
	var color_key := "start_inner_color" if start_edge else "end_inner_color"
	var explicit_color = gap.get(color_key)
	if explicit_color != null:
		return explicit_color
	var suppress_key := "start_suppress_wave" if start_edge else "end_suppress_wave"
	return _safe_gap_suppress_color(gap.get(suppress_key))


func _draw_enemy_danger_node(point: Vector2) -> void:
	draw_circle(point, 30.0, Color(1.0, 0.03, 0.12, 0.22))
	draw_circle(point, 15.0, Color(1.0, 0.08, 0.18, 0.62))
	draw_circle(point, 6.0, Color(1.0, 0.90, 0.92, 0.95))
	draw_line(point + Vector2(-17, 0), point + Vector2(17, 0), Color(1.0, 0.68, 0.72, 0.72), 2.0, true)
	draw_line(point + Vector2(0, -17), point + Vector2(0, 17), Color(1.0, 0.68, 0.72, 0.72), 2.0, true)


func _draw_player_resonance_node(point: Vector2, resonance_type: String) -> void:
	var outer := Color(0.10, 0.45, 1.0, 0.22)
	var middle := Color(0.24, 0.72, 1.0, 0.58)
	var line := Color(0.72, 0.94, 1.0, 0.72)
	if resonance_type == "violet_violet":
		outer = Color(0.52, 0.12, 0.86, 0.26)
		middle = Color(0.78, 0.26, 1.0, 0.66)
		line = Color(0.92, 0.68, 1.0, 0.80)
	draw_circle(point, RESONANCE_NODE_RADIUS, outer)
	draw_circle(point, 14.0, middle)
	draw_circle(point, 5.0, Color(0.96, 0.94, 1.0, 0.96))
	draw_line(point + Vector2(-16, 0), point + Vector2(16, 0), line, 2.0, true)
	draw_line(point + Vector2(0, -16), point + Vector2(0, 16), line, 2.0, true)


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
