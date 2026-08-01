class_name DeveloperWaveGeometry
extends RefCounted

const EPSILON := 0.0001
const SPIRAL_MAX_TURNS := 3.0
const SPIRAL_SHORT_TURNS := 1.5
const SPIRAL_TURN_SPACING := ResonanceCatalog.GAME_CASCADE_SPACING
const SPIRAL_PITCH := SPIRAL_TURN_SPACING / TAU
const SPIRAL_POINT_CROSSINGS_PER_SOURCE_PER_CASCADE := 1.0
const SPIRAL_OMEGA := TAU * SPIRAL_POINT_CROSSINGS_PER_SOURCE_PER_CASCADE / ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL
const SPIRAL_GROW_TIME := TAU * SPIRAL_MAX_TURNS / SPIRAL_OMEGA
const SPIRAL_SHORT_DRAIN_TIME := TAU * SPIRAL_SHORT_TURNS / SPIRAL_OMEGA
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
	var chirality := 1.0 if mode == "long" else float(wave.get("spiral_chirality", 1.0))
	var live_head := SPIRAL_OMEGA * age
	var head: float
	var tail: float
	var phase_head: float
	if mode == "long":
		head = minf(live_head, TAU * SPIRAL_MAX_TURNS)
		tail = 0.0
		phase_head = live_head
	else:
		var stop_age := float(wave.get("spiral_stop_age", INF))
		if age <= stop_age:
			head = live_head
			tail = maxf(0.0, head - TAU * SPIRAL_SHORT_TURNS)
		else:
			head = SPIRAL_OMEGA * stop_age
			var tail_at_stop := maxf(0.0, head - TAU * SPIRAL_SHORT_TURNS)
			tail = minf(head, tail_at_stop + SPIRAL_OMEGA * (age - stop_age))
		phase_head = head
	var theta_span := head - tail
	if theta_span <= EPSILON:
		return points
	var visible_turns := theta_span / TAU
	var sample_count := maxi(2, ceili(visible_turns * SPIRAL_SAMPLES_PER_TURN))
	var rotation := float(wave["angle"]) - chirality * phase_head
	for i in range(sample_count + 1):
		var theta := tail + theta_span * float(i) / float(sample_count)
		var radius := SPIRAL_PITCH * theta
		var angle := chirality * theta + rotation
		points.append(Vector2(wave["origin"]) + Vector2.from_angle(angle) * radius)
	return points


static func _line_points(wave: Dictionary) -> PackedVector2Array:
	var normal := Vector2.from_angle(wave["angle"])
	var tangent := Vector2(-normal.y, normal.x)
	var center: Vector2 = wave["origin"] + normal * wave["extent"]
	return PackedVector2Array([center - tangent * 720.0, center + tangent * 720.0])
