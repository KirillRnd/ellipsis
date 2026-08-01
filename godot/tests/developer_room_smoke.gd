extends SceneTree

const DEV_ROOM := preload("res://scenes/DeveloperRoom.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_expect(ResonanceCatalog.COLORS.size() == 7, "catalog contains seven colors")
	_expect(ResonanceCatalog.RESONANCES.size() == 13, "catalog contains thirteen resonances")
	var geometries := {}
	var compatible_pairs := 0
	for first in range(ResonanceCatalog.COLORS.size()):
		geometries[ResonanceCatalog.color_spec(first)["geometry"]] = true
		for second in range(first, ResonanceCatalog.COLORS.size()):
			if ResonanceCatalog.can_resonate(first, second):
				compatible_pairs += 1
				_expect(not ResonanceCatalog.resonance_spec(first, second).is_empty(), "compatible pair %d/%d has a resonance" % [first, second])
			else:
				_expect(ResonanceCatalog.resonance_spec(first, second).is_empty(), "non-neighbor pair %d/%d is rejected" % [first, second])
	_expect(compatible_pairs == 13, "linear color chain produces exactly thirteen pairs")
	_expect(geometries.has("circle") and geometries.has("spiral") and geometries.has("line"), "catalog exposes all three wave geometries")

	for action in ["dev_color_previous", "dev_color_next", "dev_remove_last", "dev_clear", "dev_toggle_simulation", "dev_slower", "dev_faster"]:
		_expect(InputMap.has_action(action), "developer action %s exists" % action)

	var room = DEV_ROOM.instantiate()
	root.add_child(room)
	await process_frame
	var positions := [Vector2(360, 180), Vector2(520, 210), Vector2(680, 240), Vector2(840, 270), Vector2(1000, 300), Vector2(1120, 360)]
	for index in range(positions.size()):
		room._select_color(index % ResonanceCatalog.COLORS.size())
		room._place_resonator(positions[index])
	_expect(room._resonators.size() == room.MAX_RESONATORS, "sixth placement keeps the five-resonator limit")
	_expect(room._resonators[0].sequence_id == 2, "sixth placement removes the oldest resonator by FIFO")
	room._fire_volley()
	_expect(room._waves.size() == room.MAX_RESONATORS, "volley creates one wave per active resonator")
	for wave in room._waves:
		if wave["geometry"] == "spiral":
			_expect(wave["spiral_mode"] == "short" and not wave["persistent"], "manual volley creates the short attached spiral")
	room._clear_room()
	_expect(room._resonators.is_empty() and room._waves.is_empty(), "clear removes sources and waves")
	room._load_preset(6) # Z/Z
	room._fire_cascade_step()
	_expect(room._waves.size() == 2, "continuous Z/Z starts one long spiral per resonator")
	room._fire_cascade_step()
	_expect(room._waves.size() == 2, "continuous cascade does not stack long spirals")
	for wave in room._waves:
		_expect(wave["spiral_mode"] == "long" and wave["persistent"], "continuous green wave is a persistent long spiral")

	var base_spiral := {"geometry": "spiral", "origin": Vector2.ZERO, "angle": 0.0, "age": 2.0, "spiral_chirality": 1.0}
	var short_spiral := base_spiral.duplicate()
	short_spiral["spiral_mode"] = "short"
	var short_points := DeveloperWaveGeometry.front_points(short_spiral)
	_expect(is_equal_approx(short_points[-1].length() - short_points[0].length(), DeveloperWaveGeometry.SPIRAL_PITCH * TAU * 1.5), "short spiral window remains exactly 1.5 turns")
	_expect(short_points[0].length() > 0.0, "short spiral tail detaches from the center after erasing begins")
	_expect(absf(short_points[-1].y) < 0.001 and short_points[-1].x > 0.0, "short spiral head stays on its fixed emission ray")
	var long_spiral := base_spiral.duplicate()
	long_spiral["spiral_mode"] = "long"
	var long_points := DeveloperWaveGeometry.front_points(long_spiral)
	_expect(is_equal_approx(long_points[-1].length(), DeveloperWaveGeometry.SPIRAL_PITCH * TAU * 3.0), "long spiral stops growing at three turns")
	room.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("developer_room_smoke: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("developer_room_smoke: %s" % failure)
	quit(1)
