class_name DeveloperResonanceRenderer
extends RefCounted

const INK := Color(0.96, 0.97, 1.0, 0.92)
const CURVE_UNIT := 72.0
const BUSH_INITIAL_COMPLETED_BRANCHES := 1
const YY_LINE_COUNT := 13
const YY_LINE_DELAY := 0.035
const YY_LINE_REVEAL_TIME := 0.10
const YY_PLATEAU_TIME := 0.22
const YY_CYCLE_PERIODS := 2.0
const YY_CYCLE_TIME := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL * YY_CYCLE_PERIODS
const YY_FADE_TIME := YY_CYCLE_TIME - YY_PLATEAU_TIME
const YY_CENTER_LENGTH_BOOST := 1.18
const YY_PARENT_HALF_LENGTH := 0.88 * (24.0 + 92.0 * YY_PLATEAU_TIME)
const LISSAJOUS_RATIOS := [Vector2i(2, 1), Vector2i(2, 1), Vector2i(3, 2), Vector2i(4, 3)]
const LISSAJOUS_PRECESSION_PERIODS := 8.0
const LISSAJOUS_TRAIL_FRACTION := 0.18
const LISSAJOUS_CURVE_SEGMENTS := 192
const LISSAJOUS_TRAIL_SEGMENTS := 48
const LISSAJOUS_TRAIL_CHUNKS := 8
const LISSAJOUS_PROJECTION_TRAIL_SAMPLES := 12
const GOLDEN_RATIO := 1.61803398875
const KG_FINAL_DIAMETER_TO_CASCADE_SPACING := 0.92
const KG_BASE_OUTER_RADIUS := ResonanceCatalog.GAME_CASCADE_SPACING * KG_FINAL_DIAMETER_TO_CASCADE_SPACING * 0.5 / (GOLDEN_RATIO * GOLDEN_RATIO)
const DELAUNAY_COCIRCULAR_TOLERANCE := 0.08
const CYAN_ROSETTE_LAYERS := [1, 3]
const CYAN_ROSETTE_SOURCE_LAUNCH_TIMES := [0.00, 0.14, 0.30, 0.48]
const CYAN_ROSETTE_SOURCE_BASE_SPEED := 1.22
const CYAN_ROSETTE_SOURCE_HARMONIC := 6.0
const CYAN_ROSETTE_CURVE_SEGMENTS := 360
const CYAN_ROSETTE_INSET := 0.92
const CYAN_ROSETTE_MIN_RADIUS := 4.0
const GY_TILE_DELAY := 0.05
const GY_TILE_REVEAL_TIME := 0.13
const GY_REVEAL_MANHATTAN_RADIUS := 2
const GLOBAL_SEED_LEAD_TIME := 0.10
const GG_TILE_EDGE_SCALE := 0.42
const GG_REVEAL_RADIUS_SCALE := 1.18
const GG_TILE_DELAY := 0.055
const GG_TILE_REVEAL_TIME := 0.13
const CURVE_DATA = preload("res://scripts/dev/ResonanceCurveData.gd")
const INFINITE_PENROSE = preload("res://scripts/dev/InfinitePenroseGrid.gd")


static func draw_same_color(canvas: CanvasItem, resonance_id: String, groups: Array, arena: Rect2, phase: float) -> void:
	match resonance_id:
		"ff":
			_draw_lissajous_groups(canvas, groups, phase)
		"ss":
			_draw_guarded_delaunay_edges(canvas, _unique_points(groups), groups, _group_color(groups))
		"gg":
			_draw_rosettes(canvas, groups, phase)
		"zz":
			_draw_gielis_leaves(canvas, groups, phase)
		"yy":
			_draw_sector_fans(canvas, groups)
		"gold_gold":
			_draw_penrose_tiles(canvas, groups, arena)
		"kk":
			_draw_guarded_voronoi(canvas, _unique_points(groups), groups, _group_color(groups))


static func draw_mixed(canvas: CanvasItem, resonance_id: String, groups: Array, arena: Rect2, phase: float) -> void:
	match resonance_id:
		"fs":
			_draw_lissajous_projections(canvas, groups, phase)
		"sg":
			_draw_delaunay_circumcircles(canvas, _unique_points(groups), groups, ResonanceCatalog.resonance_color(1, 2))
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
		"gold_gold":
			_render_penrose_grid(canvas, state, arena, simulation_age)


static func _draw_lissajous_groups(canvas: CanvasItem, groups: Array, _phase: float) -> void:
	var points := _unique_points(groups)
	for edge in _proximity_graph_edges(points, groups, "mst"):
		var first: Vector2 = edge["first"]
		var second: Vector2 = edge["second"]
		var center := (first + second) * 0.5
		var axis := second - first
		var distance := axis.length()
		if distance < 2.0:
			continue
		axis /= distance
		var perpendicular := Vector2(-axis.y, axis.x)
		var longitudinal := minf(30.0, distance * 0.18)
		var transverse := distance * 0.44
		var seed := int(edge["seed"])
		var ratio := _lissajous_ratio_from_seed(seed)
		var age := float(edge["age"])
		var reveal := _smoothstep(age / ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL)
		var clock := _lissajous_clock_from_seed(age, seed)
		var precession := _lissajous_precession_from_seed(age, seed)
		var color := ResonanceCatalog.resonance_color(0, 0)
		if reveal >= 1.0:
			var curve := _lissajous_curve(center, axis, perpendicular, longitudinal, transverse, ratio, precession)
			canvas.draw_polyline(curve, Color(color, 0.20), 8.0, true)
			canvas.draw_polyline(curve, Color(color, 0.62), 1.8, true)
		var trail_span := TAU * reveal if reveal < 1.0 else TAU * LISSAJOUS_TRAIL_FRACTION
		_draw_lissajous_trail(canvas, center, axis, perpendicular, longitudinal, transverse, ratio, precession, clock, trail_span, color)
		var runner := _lissajous_position(center, axis, perpendicular, longitudinal, transverse, ratio, clock, precession)
		canvas.draw_circle(runner, 7.0, Color(color.lightened(0.25), 0.24))
		canvas.draw_circle(runner, 4.0, INK)
		canvas.draw_circle(first, 3.2, Color(INK, 0.82))
		canvas.draw_circle(second, 3.2, Color(INK, 0.82))


static func _draw_guarded_delaunay_edges(canvas: CanvasItem, points: Array[Vector2], groups: Array, color: Color) -> void:
	for stage in _guarded_delaunay_stages(points, groups):
		var cluster: Array[Vector2] = stage["points"]
		var all_points: Array[Vector2] = stage["all_points"]
		var triangles: Array[Vector3i] = stage["triangles"]
		var local_step := float(stage["local_step"])
		var circles: Array[Dictionary] = []
		for triangle in triangles:
			circles.append(_circumcircle(all_points[triangle.x], all_points[triangle.y], all_points[triangle.z]))
		var edge_map := {}
		for triangle_index in range(triangles.size()):
			var triangle := triangles[triangle_index]
			for edge in [Vector2i(triangle.x, triangle.y), Vector2i(triangle.y, triangle.z), Vector2i(triangle.x, triangle.z)]:
				if edge.x >= cluster.size() or edge.y >= cluster.size():
					continue
				var key := "%d:%d" % [mini(edge.x, edge.y), maxi(edge.x, edge.y)]
				if not edge_map.has(key):
					edge_map[key] = {"edge": Vector2i(mini(edge.x, edge.y), maxi(edge.x, edge.y)), "triangles": []}
				var edge_data: Dictionary = edge_map[key]
				var attached_triangles: Array = edge_data["triangles"]
				attached_triangles.append(triangle_index)
				edge_data["triangles"] = attached_triangles
				edge_map[key] = edge_data
		for edge_data in edge_map.values():
			var attached: Array = edge_data["triangles"]
			if attached.size() == 2:
				var first_triangle_index := int(attached[0])
				var second_triangle_index := int(attached[1])
				if _triangle_uses_only_real_points(triangles[first_triangle_index], cluster.size()) and _triangle_uses_only_real_points(triangles[second_triangle_index], cluster.size()):
					if _circumcircles_are_equivalent(circles[first_triangle_index], circles[second_triangle_index], local_step):
						continue
			var edge: Vector2i = edge_data["edge"]
			canvas.draw_line(cluster[edge.x], cluster[edge.y], Color(color, 0.72), 2.0, true)
	for point in points:
		canvas.draw_circle(point, 3.2, INK)


static func _draw_lissajous_projections(canvas: CanvasItem, groups: Array, _phase: float) -> void:
	var points := _unique_points(groups)
	for edge in _proximity_graph_edges(points, groups, "gabriel"):
		var first: Vector2 = edge["first"]
		var second: Vector2 = edge["second"]
		var axis := second - first
		var distance := axis.length()
		if distance < 2.0:
			continue
		axis /= distance
		var center := (first + second) * 0.5
		var seed := int(edge["seed"])
		var ratio := _lissajous_ratio_from_seed(seed)
		var age := float(edge["age"])
		var reveal := _smoothstep(age / ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL)
		var clock := _lissajous_clock_from_seed(age, seed)
		var precession := _lissajous_precession_from_seed(age, seed)
		var coordinate := _lissajous_fast_coordinate(ratio, clock, precession)
		var half_length := distance * 0.5 * reveal
		var color := ResonanceCatalog.resonance_color(0, 1)
		var center_pulse := pow(1.0 - absf(coordinate), 4.0)
		canvas.draw_line(center - axis * half_length, center + axis * half_length, Color(color, 0.20 + 0.16 * center_pulse), 9.0, true)
		canvas.draw_line(center - axis * half_length, center + axis * half_length, Color(color, 0.78 + 0.14 * center_pulse), 2.3 + 0.8 * center_pulse, true)
		_draw_lissajous_projection_trail(canvas, center, axis, half_length, ratio, clock, precession, reveal, color)
		var runner := center + axis * half_length * coordinate
		canvas.draw_circle(runner, 7.5, Color(color.lightened(0.25), 0.24))
		canvas.draw_circle(runner, 4.5, INK)
		canvas.draw_circle(first, 3.0, Color(INK, 0.76))
		canvas.draw_circle(second, 3.0, Color(INK, 0.76))


static func _proximity_graph_edges(points: Array[Vector2], groups: Array, graph_kind: String) -> Array[Dictionary]:
	var point_ages := _unique_point_effect_ages(points, groups)
	var result: Array[Dictionary] = []
	if points.size() == 2:
		result.append(_make_proximity_edge(points[0], points[1], point_ages, groups))
		return result
	for cluster_value in _split_intersection_clouds(points, groups):
		var sparse_cluster: Array[Vector2] = cluster_value
		if sparse_cluster.size() == 2:
			result.append(_make_proximity_edge(sparse_cluster[0], sparse_cluster[1], point_ages, groups))
	for stage in _guarded_delaunay_stages(points, groups):
		var cluster: Array[Vector2] = stage["points"]
		var all_points: Array[Vector2] = stage["all_points"]
		var triangles: Array[Vector3i] = stage["triangles"]
		var local_step := float(stage["local_step"])
		var circles: Array[Dictionary] = []
		for triangle in triangles:
			circles.append(_circumcircle(all_points[triangle.x], all_points[triangle.y], all_points[triangle.z]))
		var edge_map := {}
		for triangle_index in range(triangles.size()):
			var triangle := triangles[triangle_index]
			for edge in [Vector2i(triangle.x, triangle.y), Vector2i(triangle.y, triangle.z), Vector2i(triangle.x, triangle.z)]:
				if edge.x >= cluster.size() or edge.y >= cluster.size():
					continue
				var key := "%d:%d" % [mini(edge.x, edge.y), maxi(edge.x, edge.y)]
				if not edge_map.has(key):
					edge_map[key] = {"edge": Vector2i(mini(edge.x, edge.y), maxi(edge.x, edge.y)), "triangles": []}
				var edge_data: Dictionary = edge_map[key]
				var attached_triangles: Array = edge_data["triangles"]
				attached_triangles.append(triangle_index)
				edge_data["triangles"] = attached_triangles
				edge_map[key] = edge_data
		for edge_data in edge_map.values():
			var attached: Array = edge_data["triangles"]
			if attached.size() == 2:
				var first_triangle_index := int(attached[0])
				var second_triangle_index := int(attached[1])
				if _triangle_uses_only_real_points(triangles[first_triangle_index], cluster.size()) and _triangle_uses_only_real_points(triangles[second_triangle_index], cluster.size()):
					if _circumcircles_are_equivalent(circles[first_triangle_index], circles[second_triangle_index], local_step):
						continue
			var edge: Vector2i = edge_data["edge"]
			var first := cluster[edge.x]
			var second := cluster[edge.y]
			var tolerance := maxf(1.0, local_step * DELAUNAY_COCIRCULAR_TOLERANCE)
			var accepted := true
			if graph_kind == "rng":
				accepted = _is_relative_neighborhood_edge(first, second, cluster, tolerance)
			elif graph_kind == "gabriel":
				accepted = _is_gabriel_edge(first, second, cluster, tolerance)
			if not accepted:
				continue
			result.append(_make_proximity_edge(first, second, point_ages, groups))
	if graph_kind == "mst":
		return _minimum_spanning_forest(result, points)
	return result


static func _minimum_spanning_forest(edges: Array[Dictionary], points: Array[Vector2]) -> Array[Dictionary]:
	var sorted_edges := edges.duplicate()
	sorted_edges.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return Vector2(first["first"]).distance_squared_to(Vector2(first["second"])) < Vector2(second["first"]).distance_squared_to(Vector2(second["second"]))
	)
	var point_indices := {}
	var parents: Array[int] = []
	for index in range(points.size()):
		point_indices[points[index]] = index
		parents.append(index)
	var result: Array[Dictionary] = []
	for edge in sorted_edges:
		var first_index := int(point_indices.get(Vector2(edge["first"]), -1))
		var second_index := int(point_indices.get(Vector2(edge["second"]), -1))
		if first_index < 0 or second_index < 0:
			continue
		var first_root := _disjoint_set_root(parents, first_index)
		var second_root := _disjoint_set_root(parents, second_index)
		if first_root == second_root:
			continue
		parents[second_root] = first_root
		result.append(edge)
	return result


static func _disjoint_set_root(parents: Array[int], index: int) -> int:
	var root := index
	while parents[root] != root:
		root = parents[root]
	while parents[index] != index:
		var parent := parents[index]
		parents[index] = root
		index = parent
	return root


static func _make_proximity_edge(first: Vector2, second: Vector2, point_ages: Dictionary, groups: Array) -> Dictionary:
	var first_seed := _point_lissajous_seed(first, groups)
	var second_seed := _point_lissajous_seed(second, groups)
	return {
		"first": first,
		"second": second,
		"age": minf(float(point_ages.get(first, 0.0)), float(point_ages.get(second, 0.0))),
		"seed": mini(first_seed, second_seed) * 97 + maxi(first_seed, second_seed) * 53,
	}


static func _is_gabriel_edge(first: Vector2, second: Vector2, points: Array[Vector2], tolerance: float = 0.0) -> bool:
	var center := (first + second) * 0.5
	var radius := first.distance_to(second) * 0.5
	for point in points:
		if point.is_equal_approx(first) or point.is_equal_approx(second):
			continue
		if point.distance_to(center) < radius - tolerance:
			return false
	return true


static func _is_relative_neighborhood_edge(first: Vector2, second: Vector2, points: Array[Vector2], tolerance: float = 0.0) -> bool:
	var distance := first.distance_to(second)
	for point in points:
		if point.is_equal_approx(first) or point.is_equal_approx(second):
			continue
		if maxf(point.distance_to(first), point.distance_to(second)) < distance - tolerance:
			return false
	return true


static func _point_lissajous_seed(point: Vector2, groups: Array) -> int:
	var seed := 0
	var found := false
	for group in groups:
		for point_value in group["points"]:
			if point.distance_squared_to(Vector2(point_value)) >= 16.0:
				continue
			var candidate := _lissajous_seed(group)
			if not found or candidate < seed:
				seed = candidate
				found = true
	return seed


static func _lissajous_seed(group: Dictionary) -> int:
	var first: Dictionary = group["first"]
	var second: Dictionary = group["second"]
	var first_volley := mini(int(first.get("volley_index", 0)), int(second.get("volley_index", 0)))
	var second_volley := maxi(int(first.get("volley_index", 0)), int(second.get("volley_index", 0)))
	var first_source := mini(int(first.get("source_id", 0)), int(second.get("source_id", 0)))
	var second_source := maxi(int(first.get("source_id", 0)), int(second.get("source_id", 0)))
	return first_volley * 97 + second_volley * 53 + first_source * 29 + second_source * 17


static func _lissajous_ratio(group: Dictionary) -> Vector2i:
	return _lissajous_ratio_from_seed(_lissajous_seed(group))


static func _lissajous_ratio_from_seed(seed: int) -> Vector2i:
	return Vector2i(LISSAJOUS_RATIOS[posmod(seed, LISSAJOUS_RATIOS.size())])


static func _lissajous_phase_offset(group: Dictionary) -> float:
	return _lissajous_phase_offset_from_seed(_lissajous_seed(group))


static func _lissajous_phase_offset_from_seed(seed: int) -> float:
	return TAU * float(posmod(seed * 73, 360)) / 360.0


static func _lissajous_clock(age: float, group: Dictionary) -> float:
	return _lissajous_clock_from_seed(age, _lissajous_seed(group))


static func _lissajous_clock_from_seed(age: float, seed: int) -> float:
	return TAU * age / ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL + _lissajous_phase_offset_from_seed(seed)


static func _lissajous_precession(age: float, group: Dictionary) -> float:
	return _lissajous_precession_from_seed(age, _lissajous_seed(group))


static func _lissajous_precession_from_seed(age: float, seed: int) -> float:
	var period := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL * LISSAJOUS_PRECESSION_PERIODS
	return TAU * age / period + _lissajous_phase_offset_from_seed(seed) * 0.5


static func _lissajous_fast_coordinate(ratio: Vector2i, t: float, precession: float) -> float:
	return sin(float(ratio.x) * t + precession)


static func _lissajous_position(center: Vector2, axis: Vector2, perpendicular: Vector2, longitudinal: float, transverse: float, ratio: Vector2i, t: float, precession: float) -> Vector2:
	var fast_coordinate := _lissajous_fast_coordinate(ratio, t, precession)
	var slow_coordinate := sin(float(ratio.y) * t)
	return center + perpendicular * longitudinal * fast_coordinate + axis * transverse * slow_coordinate


static func _lissajous_curve(center: Vector2, axis: Vector2, perpendicular: Vector2, longitudinal: float, transverse: float, ratio: Vector2i, precession: float) -> PackedVector2Array:
	var curve := PackedVector2Array()
	for index in range(LISSAJOUS_CURVE_SEGMENTS + 1):
		var t := TAU * float(index) / float(LISSAJOUS_CURVE_SEGMENTS)
		curve.append(_lissajous_position(center, axis, perpendicular, longitudinal, transverse, ratio, t, precession))
	return curve


static func _draw_lissajous_trail(canvas: CanvasItem, center: Vector2, axis: Vector2, perpendicular: Vector2, longitudinal: float, transverse: float, ratio: Vector2i, precession: float, clock: float, span: float, color: Color) -> void:
	if span <= 0.0:
		return
	for chunk in range(LISSAJOUS_TRAIL_CHUNKS):
		var curve := PackedVector2Array()
		var first_sample := int(floor(float(chunk) * float(LISSAJOUS_TRAIL_SEGMENTS) / float(LISSAJOUS_TRAIL_CHUNKS)))
		var last_sample := int(ceil(float(chunk + 1) * float(LISSAJOUS_TRAIL_SEGMENTS) / float(LISSAJOUS_TRAIL_CHUNKS)))
		for sample in range(first_sample, last_sample + 1):
			var progress := float(sample) / float(LISSAJOUS_TRAIL_SEGMENTS)
			var t := clock - span + span * progress
			curve.append(_lissajous_position(center, axis, perpendicular, longitudinal, transverse, ratio, t, precession))
		var brightness := float(chunk + 1) / float(LISSAJOUS_TRAIL_CHUNKS)
		canvas.draw_polyline(curve, Color(color, 0.08 + 0.24 * brightness), 6.0, true)
		canvas.draw_polyline(curve, Color(color.lightened(0.18), 0.22 + 0.68 * brightness), 1.8 + brightness, true)


static func _draw_lissajous_projection_trail(canvas: CanvasItem, center: Vector2, axis: Vector2, half_length: float, ratio: Vector2i, clock: float, precession: float, reveal: float, color: Color) -> void:
	var span := TAU * minf(reveal, LISSAJOUS_TRAIL_FRACTION)
	for sample in range(1, LISSAJOUS_PROJECTION_TRAIL_SAMPLES + 1):
		var progress := float(sample) / float(LISSAJOUS_PROJECTION_TRAIL_SAMPLES)
		var history_clock := clock - span + span * progress
		var coordinate := _lissajous_fast_coordinate(ratio, history_clock, precession)
		var alpha := 0.06 + 0.34 * progress * progress
		canvas.draw_circle(center + axis * half_length * coordinate, 1.4 + 1.5 * progress, Color(color.lightened(0.18), alpha))


static func _draw_delaunay_circumcircles(canvas: CanvasItem, points: Array[Vector2], groups: Array, color: Color) -> void:
	var source_distance := 320.0
	if not groups.is_empty():
		source_distance = Vector2(groups[0]["first"]["origin"]).distance_to(Vector2(groups[0]["second"]["origin"]))
	var radius_limit := source_distance * 0.55 # accepted limit 2.2 for sources four units apart
	for stage in _guarded_delaunay_stages(points, groups):
		var cluster: Array[Vector2] = stage["points"]
		var local_step := float(stage["local_step"])
		var accepted_circles: Array[Dictionary] = []
		for triangle in stage["triangles"]:
			if triangle.x >= cluster.size() or triangle.y >= cluster.size() or triangle.z >= cluster.size():
				continue
			var circle := _circumcircle(cluster[triangle.x], cluster[triangle.y], cluster[triangle.z])
			if circle.is_empty():
				continue
			var radius := sqrt(float(circle["radius_sq"]))
			if radius > radius_limit:
				continue
			var duplicate := false
			for accepted in accepted_circles:
				if _circumcircles_are_equivalent(circle, accepted, local_step):
					duplicate = true
					break
			if duplicate:
				continue
			accepted_circles.append(circle)
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
		var spacing := ResonanceCatalog.GAME_CASCADE_SPACING
		var step_gold := _solve_normal_system(normal_gold, normal_yellow, Vector2(spacing, 0.0))
		var step_yellow := _solve_normal_system(normal_gold, normal_yellow, Vector2(0.0, spacing))
		state["grid_velocity"] = _solve_normal_system(normal_gold, normal_yellow, Vector2(ResonanceCatalog.GAME_WAVE_SPEED, ResonanceCatalog.GAME_WAVE_SPEED))
		state["u"] = step_yellow / 3.0
		state["v"] = step_gold / 3.0
	var simulation_age := float(groups[0]["simulation_age"])
	var origin := _global_grid_origin(state, simulation_age)
	var u: Vector2 = state["u"]
	var v: Vector2 = state["v"]
	var determinant := u.cross(v)
	if absf(determinant) <= 0.001:
		return
	if not state.has("tile_coordinates"):
		state["tile_coordinates"] = {}
	if not state.has("tile_offsets"):
		state["tile_offsets"] = {}
	for group in groups:
		var pair_key: String = group["resonance_key"]
		var local := _update_pair_local_position(state, pair_key, group["points"], origin)
		if bool(state["scheduled_pairs"].get(pair_key, false)):
			continue
		state["scheduled_pairs"][pair_key] = true
		var seed := _nearest_lattice_vertex(local, u, v)
		# The accepted source uses a fixed cascade period, so every intersection
		# belongs to one lattice. Manual volleys have arbitrary intervals. Keep
		# the common lattice when possible, but translate an off-phase fragment
		# so its real intersection is still exactly a rhomb vertex.
		var fragment_offset := _lattice_vertex_offset(local, seed, u, v)
		var fragment_key := "global" if fragment_offset.length_squared() <= 0.0625 else pair_key
		var candidates: Array[Dictionary] = []
		for di in range(-GY_REVEAL_MANHATTAN_RADIUS, GY_REVEAL_MANHATTAN_RADIUS + 1):
			for dj in range(-GY_REVEAL_MANHATTAN_RADIUS, GY_REVEAL_MANHATTAN_RADIUS + 1):
				var shell: int = absi(di) + absi(dj)
				if shell > GY_REVEAL_MANHATTAN_RADIUS:
					continue
				candidates.append({"coordinate": seed + Vector2i(di, dj), "shell": shell, "angle": atan2(float(dj), float(di)) if di != 0 or dj != 0 else -PI})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["shell"]) < int(b["shell"]) or (int(a["shell"]) == int(b["shell"]) and float(a["angle"]) < float(b["angle"]))
		)
		var pair_birth := simulation_age - float(group.get("effect_age", 0.0))
		for order in range(candidates.size()):
			var coordinate: Vector2i = candidates[order]["coordinate"]
			var tile_key := "%s|%d:%d" % [fragment_key, coordinate.x, coordinate.y]
			var scheduled := pair_birth + float(order) * GY_TILE_DELAY
			if coordinate == seed:
				scheduled = pair_birth - GLOBAL_SEED_LEAD_TIME
			state["tile_births"][tile_key] = minf(float(state["tile_births"].get(tile_key, INF)), scheduled)
			state["tile_coordinates"][tile_key] = coordinate
			state["tile_offsets"][tile_key] = Vector2.ZERO if fragment_key == "global" else fragment_offset
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
		var coordinate: Vector2i = state["tile_coordinates"].get(tile_key, Vector2i.ZERO)
		var offset: Vector2 = state["tile_offsets"].get(tile_key, Vector2.ZERO)
		var p0 := origin + offset + float(coordinate.x) * u + float(coordinate.y) * v
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


static func _lattice_vertex_offset(local: Vector2, coordinate: Vector2i, u: Vector2, v: Vector2) -> Vector2:
	return local - float(coordinate.x) * u - float(coordinate.y) * v


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


static func _guarded_delaunay_stages(points: Array[Vector2], groups: Array) -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	for cluster_value in _split_intersection_clouds(points, groups):
		var cluster: Array[Vector2] = cluster_value
		if cluster.size() < 3:
			continue
		var local_step := _median_nearest_distance(cluster)
		if local_step < 1.0:
			local_step = 12.0
		var all_points: Array[Vector2] = cluster.duplicate()
		all_points.append_array(_build_guard_ring(cluster, local_step))
		stages.append({
			"points": cluster,
			"all_points": all_points,
			"triangles": _delaunay_triangles(all_points),
			"local_step": local_step,
		})
	return stages


static func _split_intersection_clouds(points: Array[Vector2], groups: Array) -> Array:
	if groups.is_empty():
		return [points]
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
	return [upper, lower]


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
	for group in groups:
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		var age := minf(float(first["age"]), float(second["age"]))
		var stages := clampi(int(age / 0.55) + 1, 1, 3)
		for point_value in group["points"]:
			var point: Vector2 = point_value
			for stage in range(stages):
				var outer_radius := KG_BASE_OUTER_RADIUS * pow(GOLDEN_RATIO, stage)
				var inner_radius := outer_radius * 0.52
				var star := PackedVector2Array()
				for vertex in range(11):
					var angle := -PI * 0.5 + PI * float(vertex) / 5.0 + phase * 0.025
					var radius := outer_radius if vertex % 2 == 0 else inner_radius
					star.append(point + Vector2.from_angle(angle) * radius)
				canvas.draw_polyline(star, Color(color.lightened(stage * 0.08), 0.62 + stage * 0.13), 1.5, true)


static func _draw_rosettes(canvas: CanvasItem, groups: Array, _phase: float) -> void:
	var points := _unique_points(groups)
	var point_ages := _unique_point_effect_ages(points, groups)
	var color := ResonanceCatalog.color_spec(2)["color"] as Color
	var inner_layer := int(CYAN_ROSETTE_LAYERS[0])
	var outer_layer := int(CYAN_ROSETTE_LAYERS[1])
	var inner_final_age := 1.0 - float(CYAN_ROSETTE_SOURCE_LAUNCH_TIMES[inner_layer])
	var inner_final_params := _cyan_rosette_front_params(inner_final_age, inner_layer)
	var inner_color := Color(color.lightened(0.08 * inner_layer), 0.58 + 0.10 * inner_layer)
	for stage in _guarded_delaunay_stages(points, groups):
		var cluster: Array[Vector2] = stage["points"]
		var triangles: Array[Vector3i] = stage["triangles"]
		for triangle in triangles:
			if not _triangle_uses_only_real_points(triangle, cluster.size()):
				continue
			var first := cluster[triangle.x]
			var second := cluster[triangle.y]
			var third := cluster[triangle.z]
			var incircle := _triangle_incircle(first, second, third)
			if incircle.is_empty():
				continue
			var base := float(incircle["radius"]) * CYAN_ROSETTE_INSET
			if base < CYAN_ROSETTE_MIN_RADIUS:
				continue
			var center: Vector2 = incircle["center"]
			var age := minf(float(point_ages.get(first, 0.0)), minf(float(point_ages.get(second, 0.0)), float(point_ages.get(third, 0.0))))
			var first_period := _cyan_rosette_period_progress(age, 0)
			var second_period := _cyan_rosette_period_progress(age, 1)
			if first_period > 0.0:
				if second_period <= 0.0:
					var first_profile := _cyan_rosette_profile(inner_layer, first_period)
					_draw_cyan_rosette_profile(canvas, center, base * 0.5 * first_period, first_profile, inner_color)
				else:
					var transition := second_period
					var outer_age := transition * (1.0 - float(CYAN_ROSETTE_SOURCE_LAUNCH_TIMES[outer_layer]))
					var outer_params := _cyan_rosette_front_params(outer_age, outer_layer)
					var expanded_params := inner_final_params.lerp(outer_params, transition)
					var expanded_profile := _cyan_rosette_profile_from_params(expanded_params)
					var expanded_lightening := lerpf(0.08 * inner_layer, 0.08 * outer_layer, transition)
					var expanded_alpha := lerpf(0.58 + 0.10 * inner_layer, 0.58 + 0.10 * outer_layer, transition)
					var expanded_color := Color(color.lightened(expanded_lightening), expanded_alpha)
					var shared_rotation := _cyan_rosette_profile_rotation(expanded_profile)
					_draw_cyan_rosette_profile(canvas, center, base * lerpf(0.5, 1.0, transition), expanded_profile, expanded_color, shared_rotation)
					var new_inner_profile := _cyan_rosette_profile(inner_layer, second_period)
					_draw_cyan_rosette_profile(canvas, center, base * 0.5 * second_period, new_inner_profile, inner_color, shared_rotation)


static func _cyan_rosette_period_progress(age: float, growth_step: int) -> float:
	var period := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL
	return _smoothstep((age - float(growth_step) * period) / period)


static func _cyan_rosette_front_params(source_age: float, layer: int) -> Vector4:
	var launch := float(CYAN_ROSETTE_SOURCE_LAUNCH_TIMES[layer])
	var age01 := clampf(source_age / (1.0 - launch), 0.0, 1.0)
	var growth := _smoothstep(age01)
	var radius := 0.18 + CYAN_ROSETTE_SOURCE_BASE_SPEED * source_age
	var a := (0.06 + 0.08 * float(layer)) * growth
	var b := (0.02 + 0.03 * float(layer)) * growth
	var phi := 0.7 * source_age + 0.35 * float(layer)
	return Vector4(radius, a, b, phi)


static func _cyan_rosette_radius(theta: float, params: Vector4) -> float:
	return params.x + params.y * cos(CYAN_ROSETTE_SOURCE_HARMONIC * theta + params.w) + params.z * cos(2.0 * CYAN_ROSETTE_SOURCE_HARMONIC * theta + 0.5 * params.w)


static func _cyan_rosette_profile(layer: int, progress: float) -> PackedFloat32Array:
	var source_age := clampf(progress, 0.0, 1.0) * (1.0 - float(CYAN_ROSETTE_SOURCE_LAUNCH_TIMES[layer]))
	var params := _cyan_rosette_front_params(source_age, layer)
	return _cyan_rosette_profile_from_params(params)


static func _cyan_rosette_profile_from_params(params: Vector4) -> PackedFloat32Array:
	var profile := PackedFloat32Array()
	for index in range(CYAN_ROSETTE_CURVE_SEGMENTS + 1):
		var theta := TAU * float(index) / float(CYAN_ROSETTE_CURVE_SEGMENTS)
		profile.append(_cyan_rosette_radius(theta, params))
	return profile


static func _cyan_rosette_profile_rotation(profile: PackedFloat32Array) -> float:
	var peak_index := 0
	var peak_radius := -INF
	for index in range(profile.size() - 1):
		if profile[index] > peak_radius:
			peak_radius = profile[index]
			peak_index = index
	return PI * 0.5 - TAU * float(peak_index) / float(CYAN_ROSETTE_CURVE_SEGMENTS)


static func _draw_cyan_rosette_profile(canvas: CanvasItem, center: Vector2, envelope_radius: float, profile: PackedFloat32Array, color: Color, rotation_override: float = INF) -> void:
	if envelope_radius <= 0.0 or profile.is_empty():
		return
	var peak_radius := -INF
	for index in range(profile.size() - 1):
		if profile[index] > peak_radius:
			peak_radius = profile[index]
	if peak_radius <= 0.001:
		return
	var rotation := _cyan_rosette_profile_rotation(profile) if is_inf(rotation_override) else rotation_override
	var curve := PackedVector2Array()
	for index in range(profile.size()):
		var theta := TAU * float(index) / float(CYAN_ROSETTE_CURVE_SEGMENTS)
		curve.append(center + Vector2.from_angle(theta + rotation) * envelope_radius * profile[index] / peak_radius)
	canvas.draw_polyline(curve, color, 2.0, true)


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
		var first_is_a := int(first_wave["source_id"]) < int(second_wave["source_id"])
		var wave_a: Dictionary = first_wave if first_is_a else second_wave
		var wave_b: Dictionary = second_wave if first_is_a else first_wave
		var first_angle := float(wave_a["angle"]) + PI * 0.5
		var second_angle := float(wave_b["angle"]) + PI * 0.5
		if _yy_reverse_sweep(wave_a, wave_b):
			var swap_angle := first_angle
			first_angle = second_angle
			second_angle = swap_angle
		var effect_age := float(group.get("effect_age", 0.0))
		var age := fposmod(effect_age, YY_CYCLE_TIME)
		var appear := _smoothstep(age / YY_PLATEAU_TIME)
		var fade := 1.0 - _smoothstep((age - YY_PLATEAU_TIME) / YY_FADE_TIME) if age > YY_PLATEAU_TIME else 1.0
		var global_alpha := appear * fade
		if global_alpha <= 0.0:
			continue
		var yellow := ResonanceCatalog.color_spec(4)["color"] as Color
		# Draw and animate an independent fan at every current geometric intersection.
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
				var half_length := YY_PARENT_HALF_LENGTH * center_peak * local_alpha
				canvas.draw_line(point - direction * half_length, point + direction * half_length, Color(yellow.lightened(0.24), 0.92 * global_alpha), 2.4, true)


static func _yy_reverse_sweep(wave_a: Dictionary, wave_b: Dictionary) -> bool:
	return (int(wave_a.get("volley_index", 0)) + int(wave_b.get("volley_index", 0))) % 2 != 0


static func _draw_penrose_tiles(canvas: CanvasItem, groups: Array, arena: Rect2) -> void:
	if groups.is_empty() or not groups[0].has("global_state"):
		return
	var state: Dictionary = groups[0]["global_state"]
	var first: Dictionary = groups[0]["first"]
	var second: Dictionary = groups[0]["second"]
	if not state.has("grid_velocity"):
		var normal_a := Vector2.from_angle(float(first["angle"]))
		var normal_b := Vector2.from_angle(float(second["angle"]))
		var spacing := ResonanceCatalog.GAME_CASCADE_SPACING
		var step_a := _solve_normal_system(normal_a, normal_b, Vector2(spacing, 0.0))
		var step_b := _solve_normal_system(normal_a, normal_b, Vector2(0.0, spacing))
		var typical_step := sqrt(step_a.length() * step_b.length())
		var tangent_a := Vector2(-normal_a.y, normal_a.x)
		var tangent_b := Vector2(-normal_b.y, normal_b.x)
		state["grid_velocity"] = _solve_normal_system(normal_a, normal_b, Vector2(ResonanceCatalog.GAME_WAVE_SPEED, ResonanceCatalog.GAME_WAVE_SPEED))
		state["typical_step"] = typical_step
		state["tile_edge"] = GG_TILE_EDGE_SCALE * typical_step
		state["base_angle"] = _interpolate_unoriented_angle(tangent_a.angle(), tangent_b.angle())
	var simulation_age := float(groups[0]["simulation_age"])
	var origin := _global_grid_origin(state, simulation_age)
	var tile_edge := float(state["tile_edge"])
	var base_angle := float(state["base_angle"])
	var reveal_radius := GG_REVEAL_RADIUS_SCALE * float(state["typical_step"])
	_ensure_infinite_penrose_tiles(state, arena, origin)
	var local_tiles: Dictionary = state["penrose_tiles"]
	for group in groups:
		var pair_key: String = group["resonance_key"]
		var local := _update_pair_local_position(state, pair_key, group["points"], origin)
		if bool(state["scheduled_pairs"].get(pair_key, false)):
			continue
		state["scheduled_pairs"][pair_key] = true
		var candidates: Array[Dictionary] = []
		var nearest_key := ""
		var nearest_distance := INF
		for tile_key in local_tiles:
			var center := _penrose_tile_center(local_tiles[tile_key], tile_edge, base_angle)
			var distance := center.distance_to(local)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_key = tile_key
			if distance <= reveal_radius:
				var offset := center - local
				candidates.append({"key": tile_key, "distance": distance, "angle": offset.angle()})
		var nearest_included := false
		for candidate in candidates:
			if String(candidate["key"]) == nearest_key:
				nearest_included = true
				break
		if not nearest_key.is_empty() and not nearest_included:
			var nearest_center := _penrose_tile_center(local_tiles[nearest_key], tile_edge, base_angle)
			candidates.append({"key": nearest_key, "distance": nearest_distance, "angle": (nearest_center - local).angle()})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["distance"]) < float(b["distance"]) or (is_equal_approx(float(a["distance"]), float(b["distance"])) and float(a["angle"]) < float(b["angle"])))
		var pair_birth := simulation_age - float(group.get("effect_age", 0.0))
		for order in range(candidates.size()):
			var tile_key := String(candidates[order]["key"])
			var scheduled := pair_birth + float(order) * GG_TILE_DELAY
			if tile_key == nearest_key:
				scheduled = pair_birth - GLOBAL_SEED_LEAD_TIME
			state["tile_births"][tile_key] = minf(float(state["tile_births"].get(tile_key, INF)), scheduled)
	_render_penrose_grid(canvas, state, arena, simulation_age)


static func _render_penrose_grid(canvas: CanvasItem, state: Dictionary, arena: Rect2, simulation_age: float) -> void:
	if not state.has("tile_edge"):
		return
	var origin := _global_grid_origin(state, simulation_age)
	var tile_edge := float(state["tile_edge"])
	var base_angle := float(state["base_angle"])
	_ensure_infinite_penrose_tiles(state, arena, origin)
	var local_tiles: Dictionary = state["penrose_tiles"]
	var gold := ResonanceCatalog.color_spec(5)["color"] as Color
	for tile_key in state["tile_births"]:
		if not local_tiles.has(tile_key):
			continue
		var birth := float(state["tile_births"][tile_key])
		if simulation_age < birth:
			continue
		var world := PackedVector2Array()
		var center := Vector2.ZERO
		for local_point in local_tiles[tile_key]:
			var transformed := origin + (Vector2(local_point) * tile_edge).rotated(base_angle)
			world.append(transformed)
			center += transformed
		center /= 4.0
		if not arena.grow(48.0).has_point(center):
			continue
		var alpha := _smoothstep((simulation_age - birth) / GG_TILE_REVEAL_TIME)
		world.append(world[0])
		canvas.draw_polyline(world, Color(gold.lightened(0.14), 0.82 * alpha), 1.75, true)


static func _ensure_infinite_penrose_tiles(state: Dictionary, arena: Rect2, origin: Vector2) -> void:
	var tile_edge := float(state["tile_edge"])
	var base_angle := float(state["base_angle"])
	var local_center := ((arena.get_center() - origin) / tile_edge).rotated(-base_angle)
	var visible_radius := arena.size.length() * 0.5 / tile_edge + 6.0
	var cached_center := Vector2(state.get("penrose_cache_center", Vector2(INF, INF)))
	if state.has("penrose_tiles") and cached_center.distance_to(local_center) <= 4.0:
		return
	state["penrose_cache_center"] = local_center
	state["penrose_tiles"] = INFINITE_PENROSE.tiles_around(local_center, visible_radius + 8.0)


static func _penrose_tile_center(local_tile: PackedVector2Array, tile_edge: float, base_angle: float) -> Vector2:
	var center := Vector2.ZERO
	for local_point in local_tile:
		center += (Vector2(local_point) * tile_edge).rotated(base_angle)
	return center / float(local_tile.size())


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
	var circles: Array[Dictionary] = []
	for offset in range(0, indices.size(), 3):
		var triangle := Vector3i(indices[offset], indices[offset + 1], indices[offset + 2])
		var circle := _circumcircle(all_points[triangle.x], all_points[triangle.y], all_points[triangle.z])
		if circle.is_empty():
			continue
		triangles.append(triangle)
		centers.append(circle["center"])
		circles.append(circle)
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
		var first_triangle_index := int(attached[0]["triangle"])
		var second_triangle_index := int(attached[1]["triangle"])
		if _triangle_uses_only_real_points(triangles[first_triangle_index], cluster.size()) and _triangle_uses_only_real_points(triangles[second_triangle_index], cluster.size()):
			if _circumcircles_are_equivalent(circles[first_triangle_index], circles[second_triangle_index], local_step):
				continue
		var a: Vector2 = centers[first_triangle_index]
		var b: Vector2 = centers[second_triangle_index]
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


static func _triangle_incircle(a: Vector2, b: Vector2, c: Vector2) -> Dictionary:
	var opposite_a := b.distance_to(c)
	var opposite_b := a.distance_to(c)
	var opposite_c := a.distance_to(b)
	var perimeter := opposite_a + opposite_b + opposite_c
	var double_area := absf((b - a).cross(c - a))
	if perimeter < 0.001 or double_area < 0.001:
		return {}
	var center := (a * opposite_a + b * opposite_b + c * opposite_c) / perimeter
	return {"center": center, "radius": double_area / perimeter}


static func _circumcircles_are_equivalent(first: Dictionary, second: Dictionary, local_step: float) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	var tolerance := maxf(1.0, local_step * DELAUNAY_COCIRCULAR_TOLERANCE)
	var center_distance := Vector2(first["center"]).distance_to(Vector2(second["center"]))
	var radius_difference := absf(sqrt(float(first["radius_sq"])) - sqrt(float(second["radius_sq"])))
	return center_distance <= tolerance and radius_difference <= tolerance


static func _triangle_uses_only_real_points(triangle: Vector3i, real_point_count: int) -> bool:
	return triangle.x < real_point_count and triangle.y < real_point_count and triangle.z < real_point_count


static func _unique_points(groups: Array) -> Array[Vector2]:
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
	return result


static func _unique_point_effect_ages(points: Array[Vector2], groups: Array) -> Dictionary:
	var ages := {}
	for point in points:
		var age := 0.0
		for group in groups:
			var group_age := float(group.get("effect_age", 0.0))
			for point_value in group["points"]:
				if point.distance_squared_to(Vector2(point_value)) < 16.0:
					age = maxf(age, group_age)
		ages[point] = age
	return ages


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
