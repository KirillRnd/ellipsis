class_name DeveloperWaveGeometry
extends RefCounted

const EPSILON := 0.0001
const SPIRAL_MAX_TURNS := 3.0
const SPIRAL_SHORT_TURNS := 1.5
const SPIRAL_GROW_TIME := 0.72
const SPIRAL_PITCH := 11.5
const SPIRAL_BUILD_ROTATION_PER_TURN_DEG := 25.0
const SPIRAL_ROTATION_SPEED_DEG := 68.0
const SPIRAL_SAMPLES_PER_TURN := 96.0


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
	var age := maxf(float(wave["age"]), 0.0)
	var mode: String = wave.get("spiral_mode", "short")
	var travelled_turns := SPIRAL_MAX_TURNS * age / SPIRAL_GROW_TIME
	var visible_turns := minf(SPIRAL_MAX_TURNS, travelled_turns) if mode == "long" else minf(SPIRAL_SHORT_TURNS, travelled_turns)
	if visible_turns <= 0.0:
		return points
	var first_turn := 0.0 if mode == "long" else maxf(0.0, travelled_turns - SPIRAL_SHORT_TURNS)
	var chirality := float(wave.get("spiral_chirality", 1.0))
	var theta_start := TAU * first_turn
	var theta_span := TAU * visible_turns
	var sample_count := maxi(2, ceili(visible_turns * SPIRAL_SAMPLES_PER_TURN))
	var rotation := _spiral_spring_rotation(age, chirality)
	for i in range(sample_count + 1):
		var local_theta := theta_span * float(i) / float(sample_count)
		var theta := theta_start + local_theta
		var radius := SPIRAL_PITCH * local_theta
		var angle := float(wave["angle"]) + chirality * theta + rotation
		points.append(Vector2(wave["origin"]) + Vector2.from_angle(angle) * radius)
	return points


static func _spiral_spring_rotation(age: float, chirality: float) -> float:
	var rotation_degrees: float
	if age <= SPIRAL_GROW_TIME:
		var growth := clampf(age / SPIRAL_GROW_TIME, 0.0, 1.0)
		var growing_turns := SPIRAL_MAX_TURNS * growth
		rotation_degrees = -SPIRAL_BUILD_ROTATION_PER_TURN_DEG * growth * growing_turns
	else:
		rotation_degrees = -SPIRAL_BUILD_ROTATION_PER_TURN_DEG * SPIRAL_MAX_TURNS
		rotation_degrees -= SPIRAL_ROTATION_SPEED_DEG * (age - SPIRAL_GROW_TIME)
	return deg_to_rad(rotation_degrees) * chirality


static func _line_points(wave: Dictionary) -> PackedVector2Array:
	var normal := Vector2.from_angle(wave["angle"])
	var tangent := Vector2(-normal.y, normal.x)
	var center: Vector2 = wave["origin"] + normal * wave["extent"]
	return PackedVector2Array([center - tangent * 720.0, center + tangent * 720.0])
