class_name DeveloperWaveGeometry
extends RefCounted

const EPSILON := 0.0001


static func front_points(wave: Dictionary) -> PackedVector2Array:
	match wave["geometry"]:
		"circle":
			return _circle_points(wave)
		"spiral":
			return _spiral_points(wave)
		"line":
			return _line_points(wave)
	return PackedVector2Array()


static func intersections(first: Dictionary, second: Dictionary) -> Array[Vector2]:
	if first["source_id"] == second["source_id"]:
		return []
	if first["geometry"] == "circle" and second["geometry"] == "circle":
		return circle_circle_intersections(first["origin"], first["extent"], second["origin"], second["extent"])
	return polyline_intersections(front_points(first), front_points(second))


static func circle_circle_intersections(c0: Vector2, r0: float, c1: Vector2, r1: float) -> Array[Vector2]:
	var delta := c1 - c0
	var distance := delta.length()
	if distance <= EPSILON or distance > r0 + r1 or distance < absf(r0 - r1):
		return []
	var along := (r0 * r0 - r1 * r1 + distance * distance) / (2.0 * distance)
	var height_sq := r0 * r0 - along * along
	if height_sq < -EPSILON:
		return []
	var midpoint := c0 + delta * (along / distance)
	if height_sq <= EPSILON:
		return [midpoint]
	var perpendicular := Vector2(-delta.y, delta.x) / distance * sqrt(maxf(height_sq, 0.0))
	return [midpoint + perpendicular, midpoint - perpendicular]


static func polyline_intersections(first: PackedVector2Array, second: PackedVector2Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if first.size() < 2 or second.size() < 2:
		return result
	for i in range(first.size() - 1):
		for j in range(second.size() - 1):
			var point = _segment_intersection(first[i], first[i + 1], second[j], second[j + 1])
			if point == null:
				continue
			var duplicate := false
			for existing in result:
				if existing.distance_squared_to(point) < 9.0:
					duplicate = true
					break
			if not duplicate:
				result.append(point)
	return result


static func _segment_intersection(p: Vector2, p2: Vector2, q: Vector2, q2: Vector2):
	var r := p2 - p
	var s := q2 - q
	var denominator := r.cross(s)
	if absf(denominator) <= EPSILON:
		return null
	var qp := q - p
	var t := qp.cross(s) / denominator
	var u := qp.cross(r) / denominator
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return null
	return p + r * t


static func _circle_points(wave: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(65):
		var angle := TAU * float(i) / 64.0
		points.append(wave["origin"] + Vector2.from_angle(angle) * wave["extent"])
	return points


static func _spiral_points(wave: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var theta_max := minf(6.0 * PI, wave["extent"] / 11.5)
	for i in range(73):
		var theta := theta_max * float(i) / 72.0
		var radius := 11.5 * theta
		var angle: float = theta + float(wave["angle"]) - float(wave["age"]) * 2.4
		points.append(wave["origin"] + Vector2.from_angle(angle) * radius)
	return points


static func _line_points(wave: Dictionary) -> PackedVector2Array:
	var normal := Vector2.from_angle(wave["angle"])
	var tangent := Vector2(-normal.y, normal.x)
	var center: Vector2 = wave["origin"] + normal * wave["extent"]
	return PackedVector2Array([center - tangent * 720.0, center + tangent * 720.0])
