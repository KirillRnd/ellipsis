class_name InfinitePenroseGrid
extends RefCounted

const PHASES := [0.17, 0.43, 0.69, 0.11, 0.57]
const GRID_EPSILON := 0.000001
const SAMPLE_OFFSET := 0.0001
const SEARCH_MARGIN := 3.0
const DUAL_SCALE := 2.5
const ORIGIN_SHIFT := Vector2(0.5590169944, -0.1816356320)


static func tiles_around(center: Vector2, radius: float) -> Dictionary:
	var directions := _directions()
	var pentagrid_center := (center + ORIGIN_SHIFT) / DUAL_SCALE
	var pentagrid_radius := radius / DUAL_SCALE
	var line_ranges: Array[Vector2i] = []
	for direction_index in range(5):
		var projected_center := directions[direction_index].dot(pentagrid_center) + float(PHASES[direction_index])
		line_ranges.append(Vector2i(
			floori(projected_center - pentagrid_radius - SEARCH_MARGIN),
			ceili(projected_center + pentagrid_radius + SEARCH_MARGIN),
		))
	var tiles := {}
	for first_family in range(5):
		for second_family in range(first_family + 1, 5):
			var first_direction: Vector2 = directions[first_family]
			var second_direction: Vector2 = directions[second_family]
			for first_line in range(line_ranges[first_family].x, line_ranges[first_family].y + 1):
				for second_line in range(line_ranges[second_family].x, line_ranges[second_family].y + 1):
					var intersection := _solve_lines(
						first_direction,
						second_direction,
						Vector2(float(first_line) - float(PHASES[first_family]), float(second_line) - float(PHASES[second_family])),
					)
					if intersection.distance_to(pentagrid_center) > pentagrid_radius + SEARCH_MARGIN:
						continue
					var sample := intersection - SAMPLE_OFFSET * (first_direction + second_direction)
					var base_address: Array[int] = []
					for family in range(5):
						base_address.append(ceili(directions[family].dot(sample) + float(PHASES[family]) - GRID_EPSILON))
					var addresses: Array = []
					for _corner in range(4):
						addresses.append(base_address.duplicate())
					addresses[1][first_family] += 1
					addresses[2][first_family] += 1
					addresses[2][second_family] += 1
					addresses[3][second_family] += 1
					var vertex_keys := PackedStringArray()
					var points := PackedVector2Array()
					var tile_center := Vector2.ZERO
					for address in addresses:
						vertex_keys.append(_address_key(address))
						var point := _address_position(address, directions) - ORIGIN_SHIFT
						points.append(point)
						tile_center += point
					tile_center /= 4.0
					if tile_center.distance_to(center) > radius:
						continue
					vertex_keys.sort()
					tiles["|".join(vertex_keys)] = points
	return tiles


static func _directions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(5):
		result.append(Vector2.from_angle(TAU * float(index) / 5.0))
	return result


static func _solve_lines(first: Vector2, second: Vector2, rhs: Vector2) -> Vector2:
	var determinant := first.cross(second)
	if absf(determinant) <= GRID_EPSILON:
		return Vector2.ZERO
	return Vector2(
		(rhs.x * second.y - first.y * rhs.y) / determinant,
		(first.x * rhs.y - rhs.x * second.x) / determinant,
	)


static func _address_position(address: Array, directions: Array[Vector2]) -> Vector2:
	var result := Vector2.ZERO
	for index in range(5):
		result += float(address[index]) * directions[index]
	return result


static func _address_key(address: Array) -> String:
	var components := PackedStringArray()
	for value in address:
		components.append(str(int(value)))
	return ",".join(components)
