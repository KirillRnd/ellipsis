class_name DeveloperResonanceRenderer
extends RefCounted

const INK := Color(0.96, 0.97, 1.0, 0.92)


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
			_draw_penrose_pentagrid(canvas, groups, arena, phase)
		"kk":
			_draw_guarded_voronoi(canvas, _unique_points(groups, 34), arena, _group_color(groups))


static func draw_mixed(canvas: CanvasItem, resonance_id: String, groups: Array, arena: Rect2, phase: float) -> void:
	match resonance_id:
		"fs":
			_draw_lissajous_projections(canvas, groups, phase)
		"sg":
			_draw_delaunay_circumcircles(canvas, _unique_points(groups, 32), _group_color(groups))
		"zg":
			_draw_radial_fourier(canvas, groups, phase)
		"yz":
			_draw_branching_bushes(canvas, groups)
		"gy":
			_draw_rhombic_grids(canvas, groups, arena)
		"kg":
			_draw_inflation_stars(canvas, groups, phase)


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


static func _draw_delaunay_circumcircles(canvas: CanvasItem, points: Array[Vector2], color: Color) -> void:
	for triangle in _delaunay_triangles(points):
		var circle := _circumcircle(points[triangle.x], points[triangle.y], points[triangle.z])
		if circle.is_empty():
			continue
		var radius := sqrt(float(circle["radius_sq"]))
		if radius <= 180.0:
			canvas.draw_arc(circle["center"], radius, 0.0, TAU, 72, Color(color, 0.55), 1.6, true)
	for point in points:
		canvas.draw_circle(point, 3.0, INK)


static func _draw_radial_fourier(canvas: CanvasItem, groups: Array, phase: float) -> void:
	for group in groups:
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		var green_wave: Dictionary = first if first["color_index"] == 3 else second
		var age := minf(float(first["age"]), float(second["age"]))
		var stages := clampi(int(age / 0.65) + 1, 1, 3)
		var color := ResonanceCatalog.resonance_color(2, 3)
		for point_value in group["points"]:
			var point: Vector2 = point_value
			var orientation := (point - Vector2(green_wave["origin"])).angle()
			for stage in range(stages):
				var scale := 8.0 + stage * 7.5
				var curve := PackedVector2Array()
				for index in range(81):
					var theta := TAU * float(index) / 80.0
					var radius := scale * (1.0 + 0.20 * cos(5.0 * theta + phase * 0.22) + 0.10 * sin(3.0 * theta))
					var local := Vector2(cos(theta) * radius, sin(theta) * radius * 0.72)
					curve.append(point + local.rotated(orientation))
				canvas.draw_polyline(curve, Color(color.lightened(stage * 0.07), 0.60 + stage * 0.14), 1.8, true)


static func _draw_branching_bushes(canvas: CanvasItem, groups: Array) -> void:
	var color := ResonanceCatalog.resonance_color(3, 4)
	for group in groups:
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		var green_wave: Dictionary = first if first["color_index"] == 3 else second
		var other_wave: Dictionary = second if first["color_index"] == 3 else first
		var source_axis := Vector2(other_wave["origin"]) - Vector2(green_wave["origin"])
		for point_value in group["points"]:
			var point: Vector2 = point_value
			var side := signf(source_axis.cross(point - Vector2(green_wave["origin"])))
			var trunk_direction := Vector2.from_angle(source_axis.angle() + side * PI * 0.5)
			var trunk_end := point + trunk_direction * 42.0
			canvas.draw_line(point, trunk_end, Color(color, 0.86), 2.2, true)
			for branch_index in range(5):
				var ratio := 0.20 + branch_index * 0.16
				var joint := point.lerp(trunk_end, ratio)
				var branch_side := -1.0 if branch_index % 2 == 0 else 1.0
				var direction := trunk_direction.rotated(branch_side * (0.42 + 0.05 * branch_index))
				var length := 23.0 - branch_index * 1.8
				var branch_end := joint + direction * length
				canvas.draw_line(joint, branch_end, Color(color.lightened(0.08), 0.78), 1.7, true)
				canvas.draw_line(branch_end, branch_end + direction.rotated(branch_side * 0.46) * 10.0, Color(color.lightened(0.18), 0.70), 1.2, true)


static func _draw_rhombic_grids(canvas: CanvasItem, groups: Array, _arena: Rect2) -> void:
	var color := ResonanceCatalog.resonance_color(4, 5)
	for group in groups:
		if group["points"].is_empty():
			continue
		var anchor: Vector2 = group["points"][0]
		var first: Dictionary = group["first"]
		var second: Dictionary = group["second"]
		var direction_a := Vector2.from_angle(float(first["angle"]) + PI * 0.5)
		var direction_b := Vector2.from_angle(float(second["angle"]) + PI * 0.5)
		var normal_a := Vector2(-direction_a.y, direction_a.x)
		var normal_b := Vector2(-direction_b.y, direction_b.x)
		for offset_index in range(-6, 7):
			var offset := float(offset_index) * 24.0
			var center_a := anchor + normal_a * offset
			var center_b := anchor + normal_b * offset
			canvas.draw_line(center_a - direction_a * 175.0, center_a + direction_a * 175.0, Color(color, 0.48), 1.25, true)
			canvas.draw_line(center_b - direction_b * 175.0, center_b + direction_b * 175.0, Color(color, 0.48), 1.25, true)
		canvas.draw_circle(anchor, 3.2, INK)


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
	for group in groups:
		var first_wave: Dictionary = group["first"]
		var second_wave: Dictionary = group["second"]
		var axis: Vector2 = second_wave["origin"] - first_wave["origin"]
		var axis_angle := axis.angle()
		var age := minf(float(first_wave["age"]), float(second_wave["age"]))
		var stages := clampi(int(age / 0.5) + 1, 1, 4)
		for point_value in group["points"]:
			var point: Vector2 = point_value
			var side := signf(axis.cross(point - first_wave["origin"]))
			for stage in range(stages):
				var scale := 9.0 + stage * 7.0
				var curve := _gielis_curve(point, scale, axis_angle + (PI * 0.5 * side), phase * 0.03)
				var green := ResonanceCatalog.color_spec(3)["color"] as Color
				canvas.draw_polyline(curve, Color(green.lightened(0.08 * stage), 0.58 + stage * 0.10), 1.7, true)


static func _gielis_curve(center: Vector2, scale: float, rotation: float, phase: float) -> PackedVector2Array:
	var curve := PackedVector2Array()
	for index in range(97):
		var theta := TAU * float(index) / 96.0
		var term_a := pow(absf(cos(theta)), 1.2)
		var term_b := pow(absf(sin(theta)), 1.2)
		var radius := pow(maxf(term_a + term_b, 0.0001), -1.0 / 0.42)
		var local := Vector2(cos(theta) * radius * 0.58, sin(theta) * radius * 1.25) * scale
		curve.append(center + local.rotated(rotation + phase))
	return curve


static func _draw_sector_fans(canvas: CanvasItem, groups: Array) -> void:
	for group in groups:
		var first_wave: Dictionary = group["first"]
		var second_wave: Dictionary = group["second"]
		var first_angle := float(first_wave["angle"]) + PI * 0.5
		var second_angle := float(second_wave["angle"]) + PI * 0.5
		var age := minf(float(first_wave["age"]), float(second_wave["age"]))
		var line_count := clampi(int(age * 5.0) + 1, 1, 12)
		var yellow := ResonanceCatalog.color_spec(4)["color"] as Color
		for point_value in group["points"]:
			var point: Vector2 = point_value
			for line_index in range(line_count):
				var ratio := float(line_index + 1) / float(line_count + 1)
				var angle := lerp_angle(first_angle, second_angle, ratio)
				var direction := Vector2.from_angle(angle)
				canvas.draw_line(point - direction * 130.0, point + direction * 130.0, Color(yellow.lightened(0.24), 0.52), 1.4, true)


static func _draw_penrose_pentagrid(canvas: CanvasItem, groups: Array, arena: Rect2, phase: float) -> void:
	var points := _unique_points(groups, 28)
	if points.is_empty():
		return
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var reveal_radius := 70.0 + 55.0 * minf(_minimum_group_age(groups), 3.0)
	var gold := ResonanceCatalog.color_spec(5)["color"] as Color
	for family in range(5):
		var normal := Vector2.from_angle(TAU * float(family) / 5.0 + phase * 0.015)
		var tangent := Vector2(-normal.y, normal.x)
		for offset_index in range(-5, 6):
			var offset := float(offset_index) * 27.0 + sin(family * 1.7) * 8.0
			var line_center := center + normal * offset
			var half_length := minf(reveal_radius, 190.0)
			var a := line_center - tangent * half_length
			var b := line_center + tangent * half_length
			if arena.has_point(a) or arena.has_point(b) or arena.has_point(line_center):
				canvas.draw_line(a, b, Color(gold.lightened(0.14), 0.46), 1.2, true)


static func _draw_guarded_voronoi(canvas: CanvasItem, points: Array[Vector2], arena: Rect2, color: Color) -> void:
	if points.size() < 2:
		return
	var bounds := arena.grow(-8.0)
	for site_index in range(points.size()):
		var polygon := PackedVector2Array([
			bounds.position,
			Vector2(bounds.end.x, bounds.position.y),
			bounds.end,
			Vector2(bounds.position.x, bounds.end.y),
		])
		for other_index in range(points.size()):
			if other_index == site_index:
				continue
			polygon = _clip_to_site_halfplane(polygon, points[site_index], points[other_index])
			if polygon.is_empty():
				break
		if polygon.size() >= 2:
			var closed := polygon.duplicate()
			closed.append(polygon[0])
			canvas.draw_polyline(closed, Color(color.lightened(0.18), 0.62), 1.5, true)
		canvas.draw_circle(points[site_index], 2.8, INK)


static func _clip_to_site_halfplane(polygon: PackedVector2Array, site: Vector2, other: Vector2) -> PackedVector2Array:
	var output := PackedVector2Array()
	if polygon.is_empty():
		return output
	var midpoint := (site + other) * 0.5
	var normal := other - site
	for index in range(polygon.size()):
		var current := polygon[index]
		var previous := polygon[(index - 1 + polygon.size()) % polygon.size()]
		var current_inside := (current - midpoint).dot(normal) <= 0.0
		var previous_inside := (previous - midpoint).dot(normal) <= 0.0
		if current_inside != previous_inside:
			var edge := current - previous
			var denominator := edge.dot(normal)
			if absf(denominator) > 0.0001:
				var t := (midpoint - previous).dot(normal) / denominator
				output.append(previous + edge * t)
		if current_inside:
			output.append(current)
	return output


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
	for a in range(points.size() - 2):
		for b in range(a + 1, points.size() - 1):
			for c in range(b + 1, points.size()):
				var circle := _circumcircle(points[a], points[b], points[c])
				if circle.is_empty():
					continue
				var empty := true
				for test in range(points.size()):
					if test == a or test == b or test == c:
						continue
					if points[test].distance_squared_to(circle["center"]) < float(circle["radius_sq"]) - 1.0:
						empty = false
						break
				if empty:
					result.append(Vector3i(a, b, c))
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
