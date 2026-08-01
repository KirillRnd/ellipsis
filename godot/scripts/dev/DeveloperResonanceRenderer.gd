class_name DeveloperResonanceRenderer
extends RefCounted

const INK := Color(0.96, 0.97, 1.0, 0.92)
const CURVE_UNIT := 72.0
const BUSH_INITIAL_COMPLETED_BRANCHES := 1
const YY_LINE_COUNT := 13
const YY_LINE_DELAY := 0.035
const YY_LINE_REVEAL_TIME := 0.10
const YY_PLATEAU_TIME := 0.22
const YY_FADE_TIME := 0.95
const YY_CENTER_LENGTH_BOOST := 1.18
const GY_TILE_DELAY := 0.05
const GY_TILE_REVEAL_TIME := 0.13
const GY_REVEAL_MANHATTAN_RADIUS := 2
const GLOBAL_SEED_LEAD_TIME := 0.10
const CURVE_DATA = preload("res://scripts/dev/ResonanceCurveData.gd")
const PENROSE_DATA = preload("res://scripts/dev/PenrosePatchData.gd")


static func draw_same_color(canvas: CanvasItem, resonance_id: String, groups: Array, arena: Rect2, phase: float) -> void:
	match resonance_id:
		"ff":
			_draw_lissajous_groups(canvas, groups, phase)
		"ss":
			_draw_delaunay(canvas, _unique_points(groups), _group_color(groups))
		"gg":
			_draw_rosettes(canvas, groups, phase)
		"zz":
			_draw_gielis_leaves(canvas, groups, phase)
		"yy":
			_draw_sector_fans(canvas, groups)
		"gold_gold":
			_draw_penrose_tiles(canvas, groups, arena)
		"kk":
			_draw_guarded_voronoi(canvas, _unique_points(groups, 28), groups, _group_color(groups))


static func draw_mixed(canvas: CanvasItem, resonance_id: String, groups: Array, arena: Rect2, phase: float) -> void:
	match resonance_id:
		"fs":
			_draw_lissajous_projections(canvas, groups, phase)
		"sg":
			_draw_delaunay_circumcircles(canvas, _unique_points(groups, 32), groups, ResonanceCatalog.resonance_color(1, 2))
		"zg":
			_draw_radial_fourier(canvas, groups, phase)
		"yz":
			_draw_branching_bushes(canvas, groups)
		"gy":
			_draw_rhombic_grids(canvas, groups, arena)
		"kg":
			_draw_inflation_stars(canvas, groups, phase)


static func draw_persistent_global(canvas: CanvasItem, resonance_id: String, state: Dictionary, arena: Rect2, simulation_age: float) -> void:
	match resonance_id:
		"gy":
			_render_rhombic_grid(canvas, state, arena, simulation_age)


static func _draw_lissajous_groups(canvas: CanvasItem, groups: Array, phase: float) -> void:
	for group in groups:
		var points: Array = group["points"]
		if points.size() < 2:
			continue
		var first: Vector2 = points[0]
		var second: Vector2 = points[1]
		var center := (first + second) * 0.5
		var axis := second - first
		var distance := axis.length()
		if distance < 2.0:
			continue
		axis /= distance
		var perpendicular := Vector2(-axis.y, axis.x)
		var curve := PackedVector2Array()
		for index in range(97):
			var t := TAU * float(index) / 96.0
			curve.append(center + axis * sin(t) * distance * 0.5 + perpendicular * sin(2.0 * t) * minf(42.0, distance * 0.28))
		var color := ResonanceCatalog.resonance_color(0, 0)
		canvas.draw_polyline(curve, Color(color, 0.24), 8.0, true)
		canvas.draw_polyline(curve, Color(color, 0.92), 2.4, true)
		var runner_t := fmod(phase * 1.9, TAU)
		var runner := center + axis * sin(runner_t) * distance * 0.5 + perpendicular * sin(2.0 * runner_t) * minf(42.0, distance * 0.28)
		canvas.draw_circle(runner, 4.0, INK)


static func _draw_delaunay(canvas: CanvasItem, points: Array[Vector2], color: Color) -> void:
	var edges := _delaunay_edges(points)
	for edge in edges:
		canvas.draw_line(points[edge.x], points[edge.y], Color(color, 0.72), 2.0, true)
	for point in points:
		canvas.draw_circle(point, 3.2, INK)


static func _draw_lissajous_projections(canvas: CanvasItem, groups: Array, phase: float) -> void:
	for group in groups:
		var points: Array = group["points"]
		if points.size() < 2:
			continue
		var first: Vector2 = points[0]
		var second: Vector2 = points[1]
		var color := ResonanceCatalog.resonance_color(0, 1)
		canvas.draw_line(first, second, Color(color, 0.24), 9.0, true)
		canvas.draw_line(first, second, Color(color, 0.92), 2.3, true)
		var ratio := 0.5 + 0.5 * sin(phase * 2.6)
		canvas.draw_circle(first.lerp(second, ratio), 4.5, INK)


static func _draw_delaunay_circumcircles(canvas: CanvasItem, points: Array[Vector2], groups: Array, color: Color) -> void:
	var source_distance := 320.0
	if not groups.is_empty():
		source_distance = Vector2(groups[0]["first"]["origin"]).distance_to(Vector2(groups[0]["second"]["origin"]))
	var radius_limit := source_distance * 0.55 # accepted limit 2.2 for sources four units apart
	for triangle in _delaunay_triangles(points):
		var circle := _circumcircle(points[triangle.x], points[triangle.y], points[triangle.z])
		if circle.is_empty():
			continue
		var radius := sqrt(float(circle["radius_sq"]))
		if radius <= radius_limit:
			canvas.draw_arc(circle["center"], radius, 0.0, TAU, 72, Color(color, 0.55), 1.6, true)
	for point in points:
		canvas.draw_circle(point, 3.0, INK)


static func _draw_radial_fourier(canvas: CanvasItem, groups: Array, phase: float) -> void:
	var master: PackedVector2Array = CURVE_DATA.radial_master()
	var smooth: PackedVector2Array = CURVE_DATA.radial_smooth()
	var scales := [0.58, 0.86, 1.15]
	var maturities := [0.30, 0.58, 1.00]
	for group in groups:
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		var green_wave: Dictionary = first if first["color_index"] == 3 else second
		var color := ResonanceCatalog.resonance_color(2, 3)
		for point_value in group["points"]:
			var point: Vector2 = point_value
			var spiral_parameter := point.distance_to(Vector2(green_wave["origin"])) / DeveloperWaveGeometry.SPIRAL_PITCH
			var stages := clampi(int(spiral_parameter / PI) + 1, 1, 3)
			var orientation := (point - Vector2(green_wave["origin"])).angle() - PI * 0.5
			for stage in range(stages):
				var curve := _placed_stage_curve(master, smooth, maturities[stage], point, scales[stage] * CURVE_UNIT, orientation, 1.0)
				canvas.draw_polyline(curve, Color(color.lightened(stage * 0.07), 0.64 + stage * 0.15), 1.55 + stage * 0.28, true)


static func _draw_branching_bushes(canvas: CanvasItem, groups: Array) -> void:
	var color := ResonanceCatalog.resonance_color(3, 4)
	var segments := _build_local_bush()
	for group in groups:
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		var green_wave: Dictionary = first if first["color_index"] == 3 else second
		var yellow_wave: Dictionary = first if first["color_index"] == 4 else second
		var source_axis := Vector2(yellow_wave["origin"]) - Vector2(green_wave["origin"])
		var rotation := float(yellow_wave["angle"]) + PI # turn the complete bush 180 degrees along the yellow line
		var age := float(group.get("effect_age", 0.0)) + float(BUSH_INITIAL_COMPLETED_BRANCHES) * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL
		for point_value in group["points"]:
			var point: Vector2 = point_value
			var side := 1.0 if source_axis.cross(point - Vector2(green_wave["origin"])) >= 0.0 else -1.0
			for segment in segments:
				var progress := clampf((age - float(segment["birth"])) / float(segment["growth_duration"]), 0.0, 1.0)
				if progress <= 0.0:
					continue
				var local_a: Vector2 = segment["start"]
				var local_b: Vector2 = local_a.lerp(Vector2(segment["end"]), _smoothstep(progress))
				local_a.y *= side
				local_b.y *= side
				var a := point + (local_a * 43.2).rotated(rotation)
				var b := point + (local_b * 43.2).rotated(rotation)
				canvas.draw_line(a, b, Color(color, 0.86), 1.8, true)


static func _draw_rhombic_grids(canvas: CanvasItem, groups: Array, _arena: Rect2) -> void:
	if groups.is_empty() or not groups[0].has("global_state"):
		return
	var state: Dictionary = groups[0]["global_state"]
	var first: Dictionary = groups[0]["first"]
	var second: Dictionary = groups[0]["second"]
	var gold_wave: Dictionary = first if first["color_index"] == 5 else second
	var yellow_wave: Dictionary = first if first["color_index"] == 4 else second
	if not state.has("grid_velocity"):
		var normal_gold := Vector2.from_angle(float(gold_wave["angle"]))
		var normal_yellow := Vector2.from_angle(float(yellow_wave["angle"]))
		var direction_gold := Vector2.from_angle(float(gold_wave["angle"]) + PI * 0.5)
		var direction_yellow := Vector2.from_angle(float(yellow_wave["angle"]) + PI * 0.5)
		var spacing := ResonanceCatalog.GAME_CASCADE_SPACING
		var step_gold := _solve_normal_system(normal_gold, normal_yellow, Vector2(spacing, 0.0))
		var step_yellow := _solve_normal_system(normal_gold, normal_yellow, Vector2(0.0, spacing))
		var edge_length := sqrt(step_gold.length() * step_yellow.length()) / 3.0
		state["grid_velocity"] = _solve_normal_system(normal_gold, normal_yellow, Vector2(ResonanceCatalog.GAME_WAVE_SPEED, ResonanceCatalog.GAME_WAVE_SPEED))
		state["u"] = direction_gold * edge_length
		state["v"] = direction_yellow * edge_length
	var simulation_age := float(groups[0]["simulation_age"])
	var origin := _global_grid_origin(state, simulation_age)
	var u: Vector2 = state["u"]
	var v: Vector2 = state["v"]
	var determinant := u.cross(v)
	if absf(determinant) <= 0.001:
		return
	for group in groups:
		var pair_key: String = group["resonance_key"]
		var local := _update_pair_local_position(state, pair_key, group["points"], origin)
		if bool(state["scheduled_pairs"].get(pair_key, false)):
			continue
		state["scheduled_pairs"][pair_key] = true
		var seed := _nearest_lattice_vertex(local, u, v)
		var candidates: Array[Dictionary] = []
		for di in range(-GY_REVEAL_MANHATTAN_RADIUS, GY_REVEAL_MANHATTAN_RADIUS + 1):
			for dj in range(-GY_REVEAL_MANHATTAN_RADIUS, GY_REVEAL_MANHATTAN_RADIUS + 1):
				var shell: int = absi(di) + absi(dj)
				if shell > GY_REVEAL_MANHATTAN_RADIUS:
					continue
				candidates.append({"coordinate": seed + Vector2i(di, dj), "shell": shell, "angle": atan2(float(dj), float(di)) if di != 0 or dj != 0 else -PI})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["shell"]) < int(b["shell"]) or (int(a["shell"]) == int(b["shell"]) and float(a["angle"]) < float(b["angle"]))
		var pair_birth := simulation_age - float(group.get("effect_age", 0.0))
		for order in range(candidates.size()):
			var coordinate: Vector2i = candidates[order]["coordinate"]
			var tile_key := "%d:%d" % [coordinate.x, coordinate.y]
			var scheduled := pair_birth + float(order) * GY_TILE_DELAY
			if coordinate == seed:
				scheduled = pair_birth - GLOBAL_SEED_LEAD_TIME
			state["tile_births"][tile_key] = minf(float(state["tile_births"].get(tile_key, INF)), scheduled)
	_render_rhombic_grid(canvas, state, _arena, simulation_age)


static func _render_rhombic_grid(canvas: CanvasItem, state: Dictionary, arena: Rect2, simulation_age: float) -> void:
	if not state.has("u"):
		return
	var origin := _global_grid_origin(state, simulation_age)
	var u: Vector2 = state["u"]
	var v: Vector2 = state["v"]
	var color := ResonanceCatalog.resonance_color(4, 5)
	for tile_key in state["tile_births"]:
		var birth := float(state["tile_births"][tile_key])
		if simulation_age < birth:
			continue
		var parts := String(tile_key).split(":")
		var coordinate := Vector2i(int(parts[0]), int(parts[1]))
		var p0 := origin + float(coordinate.x) * u + float(coordinate.y) * v
		var center := p0 + 0.5 * (u + v)
		if not arena.grow(48.0).has_point(center):
			continue
		var alpha := _smoothstep((simulation_age - birth) / GY_TILE_REVEAL_TIME)
		var tile := PackedVector2Array([p0, p0 + u, p0 + u + v, p0 + v, p0])
		canvas.draw_polyline(tile, Color(color, 0.76 * alpha), 1.65, true)


static func _global_grid_origin(state: Dictionary, simulation_age: float) -> Vector2:
	return Vector2(state["anchor"]) + Vector2(state.get("grid_velocity", Vector2.ZERO)) * (simulation_age - float(state["birth_time"]))


static func _update_pair_local_position(state: Dictionary, pair_key: String, points: Array, origin: Vector2) -> Vector2:
	var sample := Vector2.ZERO
	for point in points:
		sample += Vector2(point) - origin
	sample /= float(maxi(1, points.size()))
	var count := int(state["pair_sample_counts"].get(pair_key, 0))
	var previous := Vector2(state["pair_local_positions"].get(pair_key, sample))
	var averaged := (previous * float(count) + sample) / float(count + 1)
	state["pair_local_positions"][pair_key] = averaged
	state["pair_sample_counts"][pair_key] = count + 1
	return averaged


static func _nearest_lattice_vertex(local: Vector2, u: Vector2, v: Vector2) -> Vector2i:
	var determinant := u.cross(v)
	var approximate := Vector2(local.cross(v) / determinant, u.cross(local) / determinant)
	var base := Vector2i(roundi(approximate.x), roundi(approximate.y))
	var best := base
	var best_distance := INF
	for di in range(-1, 2):
		for dj in range(-1, 2):
			var candidate := Vector2i(base.x + di, base.y + dj)
			var distance := local.distance_squared_to(float(candidate.x) * u + float(candidate.y) * v)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best


static func _build_local_bush() -> Array[Dictionary]:
	var shoots := {}
	shoots["M1"] = _build_shoot(Vector2.ZERO, 90.0, Vector2(0.00, 1.00), 6, 0.96, 0.0, 0.70, 1.5, 0)
	shoots["M2"] = _build_shoot(shoots["M1"]["points"][1], shoots["M1"]["angles"][0], Vector2(-0.32, 0.80), 4, 0.82, 34.0, 0.65, 2.5, 0)
	shoots["M3"] = _build_shoot(shoots["M1"]["points"][2], shoots["M1"]["angles"][1], Vector2(0.31, 0.79), 4, 0.82, -32.0, 0.65, 2.5, 1)
	shoots["M4"] = _build_shoot(shoots["M2"]["points"][1], shoots["M2"]["angles"][0], Vector2(-0.56, 0.56), 3, 0.76, 24.0, 0.65, 3.0, 1)
	shoots["M5"] = _build_shoot(shoots["M3"]["points"][1], shoots["M3"]["angles"][0], Vector2(0.55, 0.62), 3, 0.76, -24.0, 0.65, 3.0, 0)
	var result: Array[Dictionary] = []
	var branch_names := ["M1", "M2", "M3", "M4", "M5"]
	for branch_index in range(branch_names.size()):
		var name: String = branch_names[branch_index]
		var branch_segments: Array = shoots[name]["segments"]
		var segment_duration := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL / float(branch_segments.size())
		for index in range(branch_segments.size()):
			var segment: Dictionary = shoots[name]["segments"][index]
			segment["birth"] = (float(branch_index) * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL) + float(index) * segment_duration
			segment["growth_duration"] = segment_duration
			segment["branch_index"] = branch_index
			result.append(segment)
	return result


static func _build_shoot(start: Vector2, parent_angle: float, target: Vector2, count: int, ratio: float, split_angle: float, steering: float, alternation: float, phase: int) -> Dictionary:
	var points: Array[Vector2] = [start]
	var angles: Array[float] = []
	var segments: Array[Dictionary] = []
	var first_length := start.distance_to(target) * (1.0 - ratio) / (1.0 - pow(ratio, count))
	var angle := parent_angle + split_angle
	for index in range(count):
		if index > 0:
			var desired := rad_to_deg((target - points[-1]).angle())
			angle += steering * wrapf(desired - angle, -180.0, 180.0) + alternation * (-1.0 if (index + phase) % 2 else 1.0)
		var length := first_length * pow(ratio, index)
		var next := points[-1] + Vector2.from_angle(deg_to_rad(angle)) * length
		if (target - points[-1]).dot(next - points[-1]) <= 0.0:
			angle = rad_to_deg((target - points[-1]).angle())
			next = points[-1] + Vector2.from_angle(deg_to_rad(angle)) * length
		segments.append({"start": points[-1], "end": next})
		points.append(next)
		angles.append(angle)
	return {"points": points, "angles": angles, "segments": segments}


static func _solve_normal_system(first: Vector2, second: Vector2, rhs: Vector2) -> Vector2:
	var determinant := first.cross(second)
	if absf(determinant) < 0.001:
		return Vector2.ZERO
	return Vector2((rhs.x * second.y - first.y * rhs.y) / determinant, (first.x * rhs.y - rhs.x * second.x) / determinant)


static func _interpolate_unoriented_angle(first: float, second: float) -> float:
	var difference := fposmod(second - first + PI * 0.5, PI) - PI * 0.5
	return first + 0.5 * difference


static func _median_nearest_distance(points: Array[Vector2]) -> float:
	var nearest: Array[float] = []
	for index in range(points.size()):
		var distance := INF
		for other in range(points.size()):
			if index != other:
				distance = minf(distance, points[index].distance_to(points[other]))
		if not is_inf(distance):
			nearest.append(distance)
	nearest.sort()
	if nearest.is_empty():
		return 0.0
	return nearest[floori(float(nearest.size()) * 0.5)]


static func _build_guard_ring(cluster: Array[Vector2], local_step: float) -> Array[Vector2]:
	var hull := _convex_hull(cluster)
	var guards: Array[Vector2] = []
	var distance := 1.45 * local_step
	var edge_step := 0.95 * local_step
	if hull.size() == 1:
		for index in range(6):
			guards.append(hull[0] + Vector2.from_angle(TAU * float(index) / 6.0) * distance)
		return guards
	for index in range(hull.size()):
		var previous: Vector2 = hull[(index - 1 + hull.size()) % hull.size()]
		var current: Vector2 = hull[index]
		var next: Vector2 = hull[(index + 1) % hull.size()]
		var incoming := (current - previous).normalized()
		var outgoing := (next - current).normalized()
		var normal_in := Vector2(incoming.y, -incoming.x)
		var normal_out := Vector2(outgoing.y, -outgoing.x)
		var bisector := (normal_in + normal_out).normalized()
		if bisector.length_squared() < 0.001:
			bisector = (current - _average_points(hull)).normalized()
		guards.append(current + bisector * distance)
	for index in range(hull.size()):
		var a: Vector2 = hull[index]
		var b: Vector2 = hull[(index + 1) % hull.size()]
		var edge := b - a
		var inner_count := maxi(0, int(floor(edge.length() / edge_step)) - 1)
		var outward := Vector2(edge.y, -edge.x).normalized()
		for inner in range(inner_count):
			var ratio := float(inner + 1) / float(inner_count + 1)
			guards.append(a.lerp(b, ratio) + outward * distance)
	return guards


static func _convex_hull(points: Array[Vector2]) -> Array[Vector2]:
	var sorted := points.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (is_equal_approx(a.x, b.x) and a.y < b.y))
	if sorted.size() <= 2:
		return sorted
	var lower: Array[Vector2] = []
	for point in sorted:
		while lower.size() >= 2 and (lower[-1] - lower[-2]).cross(point - lower[-1]) <= 0.0001:
			lower.pop_back()
		lower.append(point)
	var upper: Array[Vector2] = []
	for index in range(sorted.size() - 1, -1, -1):
		var point: Vector2 = sorted[index]
		while upper.size() >= 2 and (upper[-1] - upper[-2]).cross(point - upper[-1]) <= 0.0001:
			upper.pop_back()
		upper.append(point)
	lower.pop_back()
	upper.pop_back()
	lower.append_array(upper)
	return lower


static func _average_points(points: Array[Vector2]) -> Vector2:
	var result := Vector2.ZERO
	for point in points:
		result += point
	return result / maxf(float(points.size()), 1.0)


static func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var edge := b - a
	if edge.length_squared() < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(edge) / edge.length_squared(), 0.0, 1.0)
	return point.distance_to(a + edge * t)


static func _draw_inflation_stars(canvas: CanvasItem, groups: Array, phase: float) -> void:
	var color := ResonanceCatalog.resonance_color(5, 6)
	const PHI := 1.61803398875
	for group in groups:
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		var age := minf(float(first["age"]), float(second["age"]))
		var stages := clampi(int(age / 0.55) + 1, 1, 3)
		for point_value in group["points"]:
			var point: Vector2 = point_value
			for stage in range(stages):
				var outer_radius := 7.0 * pow(PHI, stage)
				var inner_radius := outer_radius * 0.52
				var star := PackedVector2Array()
				for vertex in range(11):
					var angle := -PI * 0.5 + PI * float(vertex) / 5.0 + phase * 0.025
					var radius := outer_radius if vertex % 2 == 0 else inner_radius
					star.append(point + Vector2.from_angle(angle) * radius)
				canvas.draw_polyline(star, Color(color.lightened(stage * 0.08), 0.62 + stage * 0.13), 1.5, true)


static func _draw_rosettes(canvas: CanvasItem, groups: Array, phase: float) -> void:
	for group in groups:
		var points: Array = group["points"]
		if points.size() < 2:
			continue
		var first: Vector2 = points[0]
		var second: Vector2 = points[1]
		var center := (first + second) * 0.5
		var base := first.distance_to(second) * 0.5
		for layer in range(4):
			var scale := float(layer + 1) / 4.0
			var curve := PackedVector2Array()
			for index in range(145):
				var theta := TAU * float(index) / 144.0
				var radius := base * scale * (0.78 + 0.17 * cos(6.0 * theta + phase * 0.35 + layer * 0.22) + 0.05 * cos(12.0 * theta))
				curve.append(center + Vector2.from_angle(theta) * radius)
			var color := ResonanceCatalog.color_spec(2)["color"] as Color
			canvas.draw_polyline(curve, Color(color.lightened(0.08 * layer), 0.58 + 0.10 * layer), 2.0, true)


static func _draw_gielis_leaves(canvas: CanvasItem, groups: Array, phase: float) -> void:
	var master: PackedVector2Array = CURVE_DATA.gielis_master()
	var smooth: PackedVector2Array = CURVE_DATA.gielis_smooth()
	var scales := [0.72, 1.02, 1.31, 1.60]
	var maturities := [0.30, 0.56, 0.80, 1.00]
	for group in groups:
		var first_wave: Dictionary = group["first"]
		var second_wave: Dictionary = group["second"]
		var axis: Vector2 = second_wave["origin"] - first_wave["origin"]
		var axis_angle := axis.angle()
		var age := minf(float(first_wave["age"]), float(second_wave["age"]))
		var stages := clampi(int(age / 0.5) + 1, 1, 4)
		for point_value in group["points"]:
			var point: Vector2 = point_value
			var side := 1.0 if axis.cross(point - Vector2(first_wave["origin"])) >= 0.0 else -1.0
			for stage in range(stages):
				var curve := _placed_stage_curve(master, smooth, maturities[stage], point, scales[stage] * CURVE_UNIT, axis_angle, side)
				var green := ResonanceCatalog.color_spec(3)["color"] as Color
				canvas.draw_polyline(curve, Color(green.lightened(0.08 * stage), 0.62 + stage * 0.11), 1.48 + stage * 0.22, true)


static func _placed_stage_curve(master: PackedVector2Array, smooth: PackedVector2Array, maturity: float, center: Vector2, scale: float, rotation: float, y_sign: float) -> PackedVector2Array:
	var curve := PackedVector2Array()
	var blend := _smoothstep(maturity)
	for index in range(master.size()):
		var local := smooth[index].lerp(master[index], blend)
		local.y *= y_sign
		curve.append(center + (local * scale).rotated(rotation))
	return curve


static func _smoothstep(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _draw_sector_fans(canvas: CanvasItem, groups: Array) -> void:
	for group in groups:
		var first_wave: Dictionary = group["first"]
		var second_wave: Dictionary = group["second"]
		var first_angle := float(first_wave["angle"]) + PI * 0.5
		var second_angle := float(second_wave["angle"]) + PI * 0.5
		var age := float(group.get("effect_age", 0.0))
		var appear := _smoothstep(age / YY_PLATEAU_TIME)
		var fade := 1.0 - _smoothstep((age - YY_PLATEAU_TIME) / YY_FADE_TIME) if age > YY_PLATEAU_TIME else 1.0
		var global_alpha := appear * fade
		if global_alpha <= 0.0:
			continue
		var parent_half_length := 0.88 * minf(_resonance_parent_half_length(first_wave), _resonance_parent_half_length(second_wave))
		var yellow := ResonanceCatalog.color_spec(4)["color"] as Color
		for point_value in group["points"]:
			var point: Vector2 = point_value
			for line_index in range(YY_LINE_COUNT):
				var local_age := age - float(line_index) * YY_LINE_DELAY
				if local_age <= 0.0:
					continue
				var ratio := float(line_index) / float(YY_LINE_COUNT - 1)
				var angle := lerp_angle(first_angle, second_angle, ratio)
				var direction := Vector2.from_angle(angle)
				var local_alpha := _smoothstep(local_age / YY_LINE_REVEAL_TIME) * fade
				var center_peak := 1.0 + (YY_CENTER_LENGTH_BOOST - 1.0) * (1.0 - absf(2.0 * ratio - 1.0))
				var half_length := parent_half_length * center_peak * local_alpha
				canvas.draw_line(point - direction * half_length, point + direction * half_length, Color(yellow.lightened(0.24), 0.92 * global_alpha), 2.4, true)


static func _resonance_parent_half_length(wave: Dictionary) -> float:
	return minf(260.0, 24.0 + 92.0 * float(wave["age"]))


static func _draw_penrose_tiles(canvas: CanvasItem, groups: Array, arena: Rect2) -> void:
	var points := _unique_points(groups, 28)
	if points.is_empty():
		return
	var first: Dictionary = groups[0]["first"]
	var second: Dictionary = groups[0]["second"]
	var normal_a := Vector2.from_angle(float(first["angle"]))
	var normal_b := Vector2.from_angle(float(second["angle"]))
	var spacing := ResonanceCatalog.GAME_CASCADE_SPACING
	var step_a := _solve_normal_system(normal_a, normal_b, Vector2(spacing, 0.0))
	var step_b := _solve_normal_system(normal_a, normal_b, Vector2(0.0, spacing))
	var typical_step := sqrt(step_a.length() * step_b.length())
	var tile_edge := clampf(0.42 * typical_step, 7.0, 34.0)
	var tangent_a := Vector2(-normal_a.y, normal_a.x)
	var tangent_b := Vector2(-normal_b.y, normal_b.x)
	var base_angle := _interpolate_unoriented_angle(tangent_a.angle(), tangent_b.angle())
	var anchor: Vector2 = points[0]
	var reveal_radius := 1.18 * typical_step
	var candidates: Array[Dictionary] = []
	for local_tile in PENROSE_DATA.tiles():
		var world := PackedVector2Array()
		var center := Vector2.ZERO
		for local_point in local_tile:
			var transformed: Vector2 = anchor + (Vector2(local_point) * tile_edge).rotated(base_angle)
			world.append(transformed)
			center += transformed
		center /= 4.0
		if not arena.grow(40.0).has_point(center):
			continue
		var nearest := INF
		for point in points:
			nearest = minf(nearest, center.distance_to(point))
		if nearest <= reveal_radius:
			candidates.append({"points": world, "distance": nearest})
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	var visible_count := clampi(int(_minimum_group_age(groups) / 0.055) + 1, 1, candidates.size())
	var gold := ResonanceCatalog.color_spec(5)["color"] as Color
	for index in range(visible_count):
		var tile: PackedVector2Array = candidates[index]["points"]
		var closed := tile.duplicate()
		closed.append(tile[0])
		canvas.draw_polyline(closed, Color(gold.lightened(0.14), 0.76), 1.65, true)


static func _draw_guarded_voronoi(canvas: CanvasItem, points: Array[Vector2], groups: Array, color: Color) -> void:
	if points.size() < 2:
		return
	var origin_a := Vector2(groups[0]["first"]["origin"])
	var origin_b := Vector2(groups[0]["second"]["origin"])
	var axis := (origin_b - origin_a).normalized()
	var baseline := (origin_a + origin_b) * 0.5
	var upper: Array[Vector2] = []
	var lower: Array[Vector2] = []
	for point in points:
		if axis.cross(point - baseline) >= 0.0:
			upper.append(point)
		else:
			lower.append(point)
	for cluster in [upper, lower]:
		_draw_guarded_cluster(canvas, cluster, origin_a, origin_b, axis, baseline, color)
	for point in points:
		canvas.draw_circle(point, 2.8, INK)


static func _draw_guarded_cluster(canvas: CanvasItem, cluster: Array[Vector2], origin_a: Vector2, origin_b: Vector2, axis: Vector2, baseline: Vector2, color: Color) -> void:
	if cluster.size() < 2:
		return
	var local_step := _median_nearest_distance(cluster)
	if local_step < 1.0:
		local_step = 12.0
	var guards := _build_guard_ring(cluster, local_step)
	var all_points: Array[Vector2] = cluster.duplicate()
	all_points.append_array(guards)
	var packed := PackedVector2Array(all_points)
	var indices := Geometry2D.triangulate_delaunay(packed)
	var triangles: Array[Vector3i] = []
	var centers: Array[Vector2] = []
	for offset in range(0, indices.size(), 3):
		var triangle := Vector3i(indices[offset], indices[offset + 1], indices[offset + 2])
		var circle := _circumcircle(all_points[triangle.x], all_points[triangle.y], all_points[triangle.z])
		if circle.is_empty():
			continue
		triangles.append(triangle)
		centers.append(circle["center"])
	var edge_map := {}
	for triangle_index in range(triangles.size()):
		var triangle := triangles[triangle_index]
		for edge in [Vector2i(triangle.x, triangle.y), Vector2i(triangle.y, triangle.z), Vector2i(triangle.z, triangle.x)]:
			var key := "%d:%d" % [mini(edge.x, edge.y), maxi(edge.x, edge.y)]
			if not edge_map.has(key):
				edge_map[key] = []
			edge_map[key].append({"triangle": triangle_index, "edge": edge})
	var source_distance := origin_a.distance_to(origin_b)
	for attached in edge_map.values():
		if attached.size() != 2:
			continue
		var edge: Vector2i = attached[0]["edge"]
		if edge.x >= cluster.size() and edge.y >= cluster.size():
			continue
		var a: Vector2 = centers[attached[0]["triangle"]]
		var b: Vector2 = centers[attached[1]["triangle"]]
		if a.distance_to(b) > 2.9 * local_step:
			continue
		var direction := b - a
		var midpoint := (a + b) * 0.5
		if absf(direction.normalized().cross(axis)) < 0.22 and absf((midpoint - baseline).cross(axis)) < source_distance * 0.03515625:
			continue
		var clearance := source_distance * 0.109375
		if _point_segment_distance(origin_a, a, b) < clearance or _point_segment_distance(origin_b, a, b) < clearance:
			continue
		canvas.draw_line(a, b, Color(color.lightened(0.18), 0.72), 1.5, true)


static func _delaunay_edges(points: Array[Vector2]) -> Array[Vector2i]:
	var edge_map := {}
	for triangle in _delaunay_triangles(points):
		for edge in [Vector2i(triangle.x, triangle.y), Vector2i(triangle.y, triangle.z), Vector2i(triangle.x, triangle.z)]:
			var key := "%d:%d" % [mini(edge.x, edge.y), maxi(edge.x, edge.y)]
			edge_map[key] = Vector2i(mini(edge.x, edge.y), maxi(edge.x, edge.y))
	var result: Array[Vector2i] = []
	for edge in edge_map.values():
		result.append(edge)
	return result


static func _delaunay_triangles(points: Array[Vector2]) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if points.size() < 3:
		return result
	var indices := Geometry2D.triangulate_delaunay(PackedVector2Array(points))
	for offset in range(0, indices.size(), 3):
		result.append(Vector3i(indices[offset], indices[offset + 1], indices[offset + 2]))
	return result


static func _circumcircle(a: Vector2, b: Vector2, c: Vector2) -> Dictionary:
	var denominator := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(denominator) < 0.001:
		return {}
	var a_sq := a.length_squared()
	var b_sq := b.length_squared()
	var c_sq := c.length_squared()
	var center := Vector2(
		(a_sq * (b.y - c.y) + b_sq * (c.y - a.y) + c_sq * (a.y - b.y)) / denominator,
		(a_sq * (c.x - b.x) + b_sq * (a.x - c.x) + c_sq * (b.x - a.x)) / denominator,
	)
	return {"center": center, "radius_sq": center.distance_squared_to(a)}


static func _unique_points(groups: Array, limit: int = 40) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for group in groups:
		for point_value in group["points"]:
			var point: Vector2 = point_value
			var duplicate := false
			for existing in result:
				if existing.distance_squared_to(point) < 16.0:
					duplicate = true
					break
			if not duplicate:
				result.append(point)
				if result.size() >= limit:
					return result
	return result


static func _group_color(groups: Array) -> Color:
	if groups.is_empty():
		return Color.WHITE
	var first: Dictionary = groups[0]["first"]
	return ResonanceCatalog.resonance_color(first["color_index"], first["color_index"])


static func _minimum_group_age(groups: Array) -> float:
	var age := INF
	for group in groups:
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		age = minf(age, minf(float(first["age"]), float(second["age"])))
	return 0.0 if is_inf(age) else age
