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
	_expect(ResonanceCatalog.can_resonate(room._waves[0]["color_index"], room._waves[3]["color_index"]), "yellow resonance accepts real intersections across different cascade indices")
	room._clear_room()
	room._load_preset(9) # Zh/G
	room._fire_cascade_step(0.125)
	_expect(is_equal_approx(float(room._waves[0]["age"]), 0.125) and is_equal_approx(float(room._waves[0]["extent"]), 0.125 * room.WAVE_SPEED), "cascade waves preserve their exact sub-frame launch age")

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
	var cascade_step_a := DeveloperResonanceRenderer._solve_normal_system(Vector2.RIGHT, Vector2.DOWN, Vector2(ResonanceCatalog.GAME_CASCADE_SPACING, 0.0))
	var cascade_step_b := DeveloperResonanceRenderer._solve_normal_system(Vector2.RIGHT, Vector2.DOWN, Vector2(0.0, ResonanceCatalog.GAME_CASCADE_SPACING))
	_expect((cascade_step_a / 3.0 * 3.0).is_equal_approx(cascade_step_a) and (cascade_step_b / 3.0 * 3.0).is_equal_approx(cascade_step_b), "repeated rhomb cascades land exactly three grid edges apart")
	var lattice_u := Vector2(12.0, 0.0)
	var lattice_v := Vector2(4.0, 9.0)
	var irregular_intersection := 2.0 * lattice_u - lattice_v + Vector2(3.2, -2.1)
	var irregular_seed := DeveloperResonanceRenderer._nearest_lattice_vertex(irregular_intersection, lattice_u, lattice_v)
	_expect(irregular_seed == Vector2i(2, -1), "rhomb grid finds the nearest lattice vertex for an irregular manual volley")
	var irregular_offset := DeveloperResonanceRenderer._lattice_vertex_offset(irregular_intersection, irregular_seed, lattice_u, lattice_v)
	var corrected_vertex := float(irregular_seed.x) * lattice_u + float(irregular_seed.y) * lattice_v + irregular_offset
	_expect(corrected_vertex.is_equal_approx(irregular_intersection), "off-phase manual volleys remain exactly vertex-anchored")
	_expect(DeveloperResonanceRenderer._lattice_vertex_offset(2.0 * lattice_u - lattice_v, Vector2i(2, -1), lattice_u, lattice_v).is_zero_approx(), "fixed-period cascades continue sharing the common rhomb lattice")
	var yy_a0 := {"volley_index": 0}
	var yy_a1 := {"volley_index": 1}
	var yy_b0 := {"volley_index": 0}
	var yy_b1 := {"volley_index": 1}
	_expect(not DeveloperResonanceRenderer._yy_reverse_sweep(yy_a0, yy_b0), "yellow checkerboard starts with an A-to-B sweep")
	_expect(DeveloperResonanceRenderer._yy_reverse_sweep(yy_a0, yy_b1) and DeveloperResonanceRenderer._yy_reverse_sweep(yy_a1, yy_b0), "yellow checkerboard reverses adjacent intersections to B-to-A")
	_expect(not DeveloperResonanceRenderer._yy_reverse_sweep(yy_a1, yy_b1), "yellow checkerboard returns diagonal intersections to A-to-B")
	_expect(is_equal_approx(DeveloperResonanceRenderer.YY_CYCLE_TIME, 2.0 * ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL), "yellow fan pulse cycle lasts exactly two cascade periods")
	_expect(is_equal_approx(DeveloperResonanceRenderer.YY_PLATEAU_TIME + DeveloperResonanceRenderer.YY_FADE_TIME, DeveloperResonanceRenderer.YY_CYCLE_TIME), "yellow fan appearance and fade exactly fill its pulse cycle")
	_expect(is_equal_approx(DeveloperResonanceRenderer.YY_PARENT_HALF_LENGTH, 0.88 * (24.0 + 92.0 * DeveloperResonanceRenderer.YY_PLATEAU_TIME)), "all yellow fan rows use the accepted bottom-row size")
	var kg_final_diameter := 2.0 * DeveloperResonanceRenderer.KG_BASE_OUTER_RADIUS * pow(DeveloperResonanceRenderer.GOLDEN_RATIO, 2.0)
	_expect(is_equal_approx(kg_final_diameter, ResonanceCatalog.GAME_CASCADE_SPACING * DeveloperResonanceRenderer.KG_FINAL_DIAMETER_TO_CASCADE_SPACING), "final gold-red stars nearly touch across one cascade step")
	_expect(DeveloperResonanceRenderer.LISSAJOUS_RATIOS == [Vector2i(2, 1), Vector2i(2, 1), Vector2i(3, 2), Vector2i(4, 3)], "Lissajous resonances use the accepted frequency family with a dominant 2-to-1 mode")
	var lissajous_group := {"first": {"volley_index": 2, "source_id": 1}, "second": {"volley_index": 5, "source_id": 2}}
	var reversed_lissajous_group := {"first": lissajous_group["second"], "second": lissajous_group["first"]}
	_expect(DeveloperResonanceRenderer._lissajous_ratio(lissajous_group) == DeveloperResonanceRenderer._lissajous_ratio(reversed_lissajous_group) and is_equal_approx(DeveloperResonanceRenderer._lissajous_phase_offset(lissajous_group), DeveloperResonanceRenderer._lissajous_phase_offset(reversed_lissajous_group)), "Lissajous mode and phase are stable under source ordering")
	var lissajous_period := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL
	_expect(is_equal_approx(DeveloperResonanceRenderer._lissajous_clock(lissajous_period, lissajous_group) - DeveloperResonanceRenderer._lissajous_clock(0.0, lissajous_group), TAU), "Lissajous runner completes one parameter cycle per cascade period")
	_expect(is_equal_approx(DeveloperResonanceRenderer._lissajous_precession(lissajous_period * 8.0, lissajous_group) - DeveloperResonanceRenderer._lissajous_precession(0.0, lissajous_group), TAU), "Lissajous phase precession completes one turn per eight cascade periods")
	_expect(is_equal_approx(DeveloperResonanceRenderer._lissajous_fast_coordinate(Vector2i(2, 1), PI * 0.25, 0.0), 1.0), "F/S projection uses the fast coordinate of the shared Lissajous oscillator")
	_expect(DeveloperResonanceRenderer._lissajous_position(Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, 4.0, 10.0, Vector2i(2, 1), PI * 0.5, 0.0).is_equal_approx(Vector2(10.0, 0.0)), "base 2-to-1 Lissajous geometry retains its node-aligned slow extremum")
	var proximity_first := Vector2(-10.0, 0.0)
	var proximity_second := Vector2(10.0, 0.0)
	var lune_only_point := Vector2(0.0, 12.0)
	var diameter_point := Vector2(0.0, 5.0)
	var lune_points: Array[Vector2] = [proximity_first, proximity_second, lune_only_point]
	var diameter_points: Array[Vector2] = [proximity_first, proximity_second, diameter_point]
	_expect(DeveloperResonanceRenderer._is_gabriel_edge(proximity_first, proximity_second, lune_points), "F/S Gabriel graph keeps an edge whose open diametral disk is empty")
	_expect(not DeveloperResonanceRenderer._is_relative_neighborhood_edge(proximity_first, proximity_second, lune_points), "F/F relative-neighborhood graph is the stricter pairwise stage before F/S")
	_expect(not DeveloperResonanceRenderer._is_gabriel_edge(proximity_first, proximity_second, diameter_points), "F/S Gabriel graph rejects an edge containing another active node in its diametral disk")
	var delaunay_groups := [{"first": {"origin": Vector2(-10.0, 0.0)}, "second": {"origin": Vector2(10.0, 0.0)}}]
	var delaunay_points: Array[Vector2] = [Vector2(-4.0, -4.0), Vector2(0.0, -6.0), Vector2(4.0, -4.0), Vector2(-4.0, 4.0), Vector2(0.0, 6.0), Vector2(4.0, 4.0)]
	var delaunay_clouds := DeveloperResonanceRenderer._split_intersection_clouds(delaunay_points, delaunay_groups)
	_expect(delaunay_clouds.size() == 2 and delaunay_clouds[0].size() == 3 and delaunay_clouds[1].size() == 3, "blue Delaunay stages split intersections into the same upper and lower clouds as red Voronoi")
	var guarded_stages := DeveloperResonanceRenderer._guarded_delaunay_stages(delaunay_points, delaunay_groups)
	_expect(guarded_stages.size() == 2, "blue edges and circumcircles share the guarded Delaunay stage")
	var many_delaunay_points: Array[Vector2] = []
	for point_index in range(65):
		many_delaunay_points.append(Vector2(float(point_index) * 8.0, 0.0))
	var complete_delaunay_points := DeveloperResonanceRenderer._unique_points([{"points": many_delaunay_points}])
	_expect(complete_delaunay_points.size() == 65, "Delaunay resonances retain every active unique intersection beyond the old display cap")
	_expect(DeveloperResonanceRenderer._triangle_uses_only_real_points(Vector3i(0, 1, 2), 3), "cocircular stabilization recognizes an entirely real Delaunay triangle")
	_expect(not DeveloperResonanceRenderer._triangle_uses_only_real_points(Vector3i(0, 1, 3), 3), "cocircular stabilization preserves triangles touching the guard ring")
	var rosette_incircle := DeveloperResonanceRenderer._triangle_incircle(Vector2.ZERO, Vector2(6.0, 0.0), Vector2(0.0, 8.0))
	_expect(Vector2(rosette_incircle["center"]).is_equal_approx(Vector2(2.0, 2.0)) and is_equal_approx(float(rosette_incircle["radius"]), 2.0), "cyan rosettes use the exact incircle of each real Delaunay triangle")
	var adjacent_rosette_incircle := DeveloperResonanceRenderer._triangle_incircle(Vector2(6.0, 0.0), Vector2(6.0, 8.0), Vector2(0.0, 8.0))
	_expect(Vector2(rosette_incircle["center"]).distance_to(Vector2(adjacent_rosette_incircle["center"])) + 0.001 >= float(rosette_incircle["radius"]) + float(adjacent_rosette_incircle["radius"]), "incircles keep cyan rosettes disjoint across a shared Delaunay edge")
	var cascade_period := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL
	_expect(DeveloperResonanceRenderer.CYAN_ROSETTE_LAYERS == [1, 3], "cyan rosettes retain only their second and fourth geometric layers")
	_expect(is_equal_approx(DeveloperResonanceRenderer._cyan_rosette_period_progress(cascade_period, 0), 1.0), "cyan rosette second layer completes during the first cascade period")
	_expect(is_zero_approx(DeveloperResonanceRenderer._cyan_rosette_period_progress(cascade_period, 1)), "cyan rosette expansion and new second layer start after the first cascade period")
	_expect(is_equal_approx(DeveloperResonanceRenderer._cyan_rosette_period_progress(cascade_period * 2.0, 1), 1.0), "cyan rosette fourth layer and new second layer complete after two cascade periods")
	var source_layer_two := DeveloperResonanceRenderer._cyan_rosette_front_params(0.86, 1)
	_expect(source_layer_two.is_equal_approx(Vector4(1.2292, 0.14, 0.05, 0.952)), "cyan rosette second-layer parameters exactly match the accepted Python source")
	var source_layer_four := DeveloperResonanceRenderer._cyan_rosette_front_params(0.52, 3)
	_expect(source_layer_four.is_equal_approx(Vector4(0.8144, 0.30, 0.11, 1.414)), "cyan rosette fourth-layer parameters exactly match the accepted Python source")
	var reference_circle := {"center": Vector2.ZERO, "radius_sq": 100.0}
	var equivalent_circle := {"center": Vector2(0.4, -0.3), "radius_sq": 102.01}
	var distinct_circle := {"center": Vector2(5.0, 0.0), "radius_sq": 100.0}
	_expect(DeveloperResonanceRenderer._circumcircles_are_equivalent(reference_circle, equivalent_circle, 10.0), "near-cocircular Delaunay alternatives share one stable visual primitive")
	_expect(not DeveloperResonanceRenderer._circumcircles_are_equivalent(reference_circle, distinct_circle, 10.0), "distinct Delaunay circumcircles remain separate visual primitives")
	var unit_tile := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	_expect(DeveloperResonanceRenderer._penrose_tile_center(unit_tile, 2.0, 0.0).is_equal_approx(Vector2.ONE), "Penrose reveal uses transformed global tile centers")
	var near_penrose_tiles: Dictionary = DeveloperResonanceRenderer.INFINITE_PENROSE.tiles_around(Vector2.ZERO, 3.0)
	var distant_penrose_tiles: Dictionary = DeveloperResonanceRenderer.INFINITE_PENROSE.tiles_around(Vector2(48.0, -31.0), 3.0)
	_expect(not near_penrose_tiles.is_empty() and not distant_penrose_tiles.is_empty(), "Penrose pentagrid generates tiles around arbitrarily distant visible regions")
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
