extends SceneTree

var _manager: WaveManager
var _tracked_objects: Array[Object] = []
var _failed := false


func _init() -> void:
	_run_test("red/red circle nodes", test_red_red_node_requires_two_present_circle_crests)
	_run_test("red/gold circle-line nodes", test_red_gold_node_requires_circle_and_line_crests)
	_run_test("gold/gold line nodes", test_gold_gold_node_requires_two_present_line_crests)
	_run_test("blue/violet resonance", test_blue_violet_resonance_requires_both_present_crests)
	_run_test("violet/violet resonance", test_violet_violet_resonance_requires_both_present_crests)
	_run_test("blue and violet cancellation", test_blue_and_violet_cancellation_remove_enemy_nodes)
	_run_test("partially erased overlap", test_one_erased_enemy_crest_does_not_hide_another_active_crest)
	_run_test("fully erased crest", test_fully_erased_enemy_crest_is_safe)
	if _failed:
		quit(1)
		return
	print("WAVE_GAP_CONSISTENCY_SMOKE_OK")
	quit()


func _run_test(test_name: String, test_method: Callable) -> void:
	_manager = track(WaveManager.new()) as WaveManager
	test_method.call()
	_free_tracked()
	if _failed:
		push_error("Wave gap consistency failed: %s" % test_name)


func track(object: Object) -> Object:
	_tracked_objects.append(object)
	return object


func _free_tracked() -> void:
	for object in _tracked_objects:
		if is_instance_valid(object):
			object.free()
	_tracked_objects.clear()


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if _failed or actual == expected:
		return
	_failed = true
	push_error("%s: expected %s, got %s" % [message, expected, actual])


func test_red_red_node_requires_two_present_circle_crests() -> void:
	var first := _wave("enemy", "red", Vector2(500.0, 300.0), 100.0)
	var second := _wave("enemy", "red", Vector2(620.0, 300.0), 100.0)
	_manager.waves = [first, second]
	var points := _manager._enemy_interference_points([])
	assert_eq(points.size(), 2, "red/red circles must initially create two danger nodes")
	if points.is_empty():
		return
	var gaps := [_gap_at(first, points[0])]
	assert_eq(
		_manager._enemy_interference_points(gaps).size(),
		1,
		"a red/red node must disappear when either red crest is erased",
	)


func test_red_gold_node_requires_circle_and_line_crests() -> void:
	var red := _wave("enemy", "red", Vector2(500.0, 300.0), 100.0)
	var gold := _wave(
		"enemy",
		"gold",
		Vector2(400.0, 300.0),
		100.0,
		{"line_direction": Vector2.RIGHT},
	)
	_manager.waves = [red, gold]
	var points := _manager._enemy_interference_points([])
	assert_eq(points.size(), 2, "red/gold fronts must initially create two danger nodes")
	if points.is_empty():
		return
	var gaps := [_gap_at(gold, points[0])]
	assert_eq(
		_manager._enemy_interference_points(gaps).size(),
		1,
		"a red/gold node must disappear when the gold line is erased",
	)


func test_gold_gold_node_requires_two_present_line_crests() -> void:
	var horizontal := _wave(
		"enemy",
		"gold",
		Vector2(500.0, 200.0),
		100.0,
		{"line_direction": Vector2.DOWN},
	)
	var vertical := _wave(
		"enemy",
		"gold",
		Vector2(400.0, 300.0),
		100.0,
		{"line_direction": Vector2.RIGHT},
	)
	_manager.waves = [horizontal, vertical]
	var points := _manager._enemy_interference_points([])
	assert_eq(points.size(), 1, "gold/gold lines must initially create one danger node")
	if points.is_empty():
		return
	var gaps := [_gap_at(vertical, points[0])]
	assert_eq(
		_manager._enemy_interference_points(gaps).size(),
		0,
		"a gold/gold node must disappear when either gold line is erased",
	)


func test_blue_violet_resonance_requires_both_present_crests() -> void:
	var blue := _wave(
		"player",
		"blue",
		Vector2(500.0, 300.0),
		100.0,
		{"can_create_resonance": true},
	)
	var violet := _wave("player", "resonator", Vector2(620.0, 300.0), 100.0)
	_manager.player_waves = [blue, violet]
	var nodes := _manager._player_resonance_nodes([])
	assert_eq(nodes.size(), 2, "blue/violet fronts must initially create two resonance nodes")
	if nodes.is_empty():
		return
	var gaps := [_gap_at(blue, nodes[0]["point"])]
	assert_eq(
		_manager._player_resonance_nodes(gaps).size(),
		1,
		"a blue/violet node must disappear when either crest is erased",
	)


func test_violet_violet_resonance_requires_both_present_crests() -> void:
	var first := _wave("player", "resonator", Vector2(500.0, 300.0), 100.0)
	var second := _wave("player", "resonator", Vector2(620.0, 300.0), 100.0)
	_manager.player_waves = [first, second]
	var nodes := _manager._player_resonance_nodes([])
	assert_eq(nodes.size(), 2, "violet/violet fronts must initially create two resonance nodes")
	if nodes.is_empty():
		return
	var gaps := [_gap_at(second, nodes[0]["point"])]
	assert_eq(
		_manager._player_resonance_nodes(gaps).size(),
		1,
		"a violet/violet node must disappear when either crest is erased",
	)


func test_blue_and_violet_cancellation_remove_enemy_nodes() -> void:
	for counter_kind in ["blue", "resonator"]:
		var first := _wave("enemy", "red", Vector2(400.0, 300.0), 150.0)
		var second := _wave("enemy", "red", Vector2(700.0, 300.0), 150.0)
		var counter := _wave("player", counter_kind, Vector2(550.0, 150.0), 150.0)
		_manager.waves = [first, second, counter]
		_manager.player_waves = [counter]
		var safe_gaps := _manager._build_safe_gaps()
		assert_eq(
			_manager._enemy_interference_points(safe_gaps).size(),
			0,
			"%s cancellation must remove a red danger node with its erased crests" % counter_kind,
		)


func test_one_erased_enemy_crest_does_not_hide_another_active_crest() -> void:
	var first := _wave("enemy", "red", Vector2(400.0, 300.0), 100.0)
	var second := _wave("enemy", "red", Vector2(600.0, 300.0), 100.0)
	var contact := Vector2(500.0, 300.0)
	var crossbar := track(SteelCrossbarDriven.new()) as SteelCrossbarDriven
	crossbar.setup(contact, Vector2.UP, false)
	_manager.waves = [first, second]
	_manager.driven_crossbar = crossbar
	assert_eq(
		_manager.get_point_danger(contact),
		1,
		"a gap in one overlapping enemy crest must not erase the other crest's damage",
	)


func test_fully_erased_enemy_crest_is_safe() -> void:
	var red := _wave("enemy", "red", Vector2(400.0, 300.0), 100.0)
	var contact := Vector2(500.0, 300.0)
	var crossbar := track(SteelCrossbarDriven.new()) as SteelCrossbarDriven
	crossbar.setup(contact, Vector2.UP, false)
	_manager.waves = [red]
	_manager.driven_crossbar = crossbar
	assert_eq(
		_manager.get_point_danger(contact),
		-1,
		"a point containing only erased enemy crests must remain a safe gap",
	)


func _wave(
	owner: String,
	kind: String,
	origin: Vector2,
	radius: float,
	config: Dictionary = {},
) -> Wave:
	var wave := track(Wave.new()) as Wave
	wave.setup(owner, kind, origin, config)
	wave.radius = radius
	return wave


func _gap_at(wave: Wave, point: Vector2) -> Dictionary:
	if wave.wave_shape == "line":
		var tangent := Vector2(-wave.line_direction.y, wave.line_direction.x)
		var base := wave.global_position + wave.line_direction * wave.radius
		var side := (point - base).dot(tangent)
		return _manager._make_safe_gap(wave, "line", side - 1.0, side + 1.0, null, null)
	var angle := _manager._normalize_angle_positive((point - wave.global_position).angle())
	return _manager._make_safe_gap(wave, "circle", angle - 0.01, angle + 0.01, null, null)
