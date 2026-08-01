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
	for preset_index in [8, 10]: # Zh/Zh and G/G
		room._clear_room()
		room._load_preset(preset_index)
		room._fire_cascade_step()
		room._fire_cascade_step()
		_expect(room._waves.size() == 4, "each straight resonator emits one line per cascade step")
	room._clear_room()
	room._load_preset(8) # Zh/Zh
	room._fire_cascade_step()
	room._fire_cascade_step()
	_expect(room._waves[0]["volley_index"] == room._waves[1]["volley_index"], "corresponding straight waves share one volley index")
	_expect(room._waves[0]["volley_index"] != room._waves[2]["volley_index"], "successive straight cascades receive distinct volley indices")

	var base_spiral := {"geometry": "spiral", "origin": Vector2.ZERO, "angle": 0.0, "age": 2.0, "spiral_chirality": 1.0}
	_expect(is_equal_approx(DeveloperWaveGeometry.SPIRAL_OMEGA * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL, TAU), "each spiral crosses a fixed point once per circle cascade period")
	_expect(is_equal_approx(DeveloperWaveGeometry.SPIRAL_OMEGA * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL * 2.0, TAU * 2.0), "two green resonators produce two fixed-point crossings per cascade period")
	_expect(is_equal_approx(DeveloperWaveGeometry.SPIRAL_PITCH * TAU, ResonanceCatalog.GAME_WAVE_SPEED * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL), "spiral turn spacing equals circle cascade spacing")
	_expect(is_equal_approx(DeveloperWaveGeometry.SPIRAL_PITCH * DeveloperWaveGeometry.SPIRAL_OMEGA, ResonanceCatalog.GAME_WAVE_SPEED), "spiral head and circle fronts share one radial speed")
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
	var mirrored_long_spiral := long_spiral.duplicate()
	mirrored_long_spiral["spiral_chirality"] = -1.0
	_expect(DeveloperWaveGeometry.front_points(mirrored_long_spiral) == long_points, "long spiral rotation does not mirror with resonator direction")
	var first_line := {"geometry": "line", "origin": Vector2.ZERO, "angle": 0.0, "extent": 0.0}
	var next_line := first_line.duplicate()
	next_line["extent"] = ResonanceCatalog.GAME_CASCADE_SPACING
	var first_line_points := DeveloperWaveGeometry.front_points(first_line)
	var next_line_points := DeveloperWaveGeometry.front_points(next_line)
	var first_line_center := (first_line_points[0] + first_line_points[1]) * 0.5
	var next_line_center := (next_line_points[0] + next_line_points[1]) * 0.5
	_expect(is_equal_approx(first_line_center.distance_to(next_line_center), ResonanceCatalog.GAME_CASCADE_SPACING), "straight cascade fronts use the shared circle spacing")
	var solved_grid_velocity := DeveloperResonanceRenderer._solve_normal_system(Vector2.RIGHT, Vector2.DOWN, Vector2(118.0, 118.0))
	_expect(solved_grid_velocity.is_equal_approx(Vector2(118.0, 118.0)), "global straight-wave grids solve both normal velocity constraints")
	var lattice_u := Vector2(12.0, 0.0)
	var lattice_v := Vector2(4.0, 9.0)
	_expect(DeveloperResonanceRenderer._nearest_lattice_vertex(2.0 * lattice_u - lattice_v + Vector2(0.2, -0.1), lattice_u, lattice_v) == Vector2i(2, -1), "rhomb grid anchors an intersection to its nearest lattice vertex")
	var bush_segments := DeveloperResonanceRenderer._build_local_bush()
	_expect(DeveloperResonanceRenderer.BUSH_INITIAL_COMPLETED_BRANCHES == 1, "branching bush animation starts directly from its second step")
	for branch_index in range(5):
		var branch_segments: Array[Dictionary] = []
		for segment in bush_segments:
			if int(segment["branch_index"]) == branch_index:
				branch_segments.append(segment)
		_expect(not branch_segments.is_empty(), "branching bush contains all five sequential branches")
		if branch_segments.is_empty():
			continue
		var branch_start: float = branch_segments[0]["birth"]
		var branch_end: float = branch_segments[-1]["birth"] + branch_segments[-1]["growth_duration"]
		_expect(is_equal_approx(branch_start, float(branch_index) * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL), "each bush branch starts after the previous cascade period")
		_expect(is_equal_approx(branch_end, float(branch_index + 1) * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL), "each bush branch grows for exactly one cascade period")
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
