extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const MAX_RESONATORS := 5
const MAX_WAVES := 40
const WAVE_SPEED := ResonanceCatalog.GAME_WAVE_SPEED
const WAVE_LIFETIME := 4.8
const CASCADE_PERIOD := ResonanceCatalog.GAME_RESONATOR_VOLLEY_INTERVAL
const ARENA_RECT := Rect2(252.0, 72.0, 996.0, 616.0)
const SPEEDS := [0.25, 0.5, 1.0, 2.0]
const PRESETS := [
	{"pair": Vector2i(0, 0), "positions": [Vector2(0.30, 0.55), Vector2(0.70, 0.55)], "angles": [0.0, PI]},
	{"pair": Vector2i(0, 1), "positions": [Vector2(0.30, 0.55), Vector2(0.70, 0.55)], "angles": [0.0, PI]},
	{"pair": Vector2i(1, 1), "positions": [Vector2(0.30, 0.55), Vector2(0.70, 0.55)], "angles": [0.0, PI]},
	{"pair": Vector2i(1, 2), "positions": [Vector2(0.30, 0.55), Vector2(0.70, 0.55)], "angles": [0.0, PI]},
	{"pair": Vector2i(2, 2), "positions": [Vector2(0.30, 0.55), Vector2(0.70, 0.55)], "angles": [0.0, PI]},
	{"pair": Vector2i(2, 3), "positions": [Vector2(0.70, 0.48), Vector2(0.32, 0.58)], "angles": [PI, -0.20]},
	{"pair": Vector2i(3, 3), "positions": [Vector2(0.32, 0.62), Vector2(0.68, 0.62)], "angles": [-0.12, PI + 0.12]},
	{"pair": Vector2i(3, 4), "positions": [Vector2(0.66, 0.52), Vector2(0.28, 0.52)], "angles": [PI, 0.0]},
	{"pair": Vector2i(4, 4), "positions": [Vector2(0.30, 0.72), Vector2(0.70, 0.72)], "angles": [-0.959931, -2.181662]},
	{"pair": Vector2i(4, 5), "positions": [Vector2(0.28, 0.72), Vector2(0.72, 0.72)], "angles": [-1.047198, -2.094395]},
	{"pair": Vector2i(5, 5), "positions": [Vector2(0.28, 0.68), Vector2(0.72, 0.68)], "angles": [-0.488692, -2.059489]},
	{"pair": Vector2i(5, 6), "positions": [Vector2(0.30, 0.66), Vector2(0.70, 0.50)], "angles": [-0.610865, 0.0]},
	{"pair": Vector2i(6, 6), "positions": [Vector2(0.30, 0.55), Vector2(0.70, 0.55)], "angles": [0.0, PI]},
]

var _settings
var _language := "ru"
var _selected_color := 0
var _next_source_id := 1
var _next_wave_id := 1
var _next_volley_index := 1
var _current_volley_index := 0
var _resonators: Array[DeveloperResonator] = []
var _waves: Array[Dictionary] = []
var _cursor_position := ARENA_RECT.get_center()
var _simulation_paused := false
var _cascade_enabled := false
var _cascade_accumulator := 0.0
var _selected_preset := -1
var _speed_index := 2
var _last_resonance_count := 0
var _last_pair_types := {}
var _last_geometry_usec := 0
var _resonance_birth_ages := {}
var _global_resonance_states := {}
var _simulation_age := 0.0

var _title_label: Label
var _selected_label: Label
var _count_label: Label
var _stats_label: Label
var _help_label: Label
var _pause_button: Button
var _speed_button: Button
var _cascade_button: Button
var _preset_menu: MenuButton
var _color_buttons: Array[Button] = []


func _ready() -> void:
	_settings = get_node_or_null("/root/Settings")
	if is_instance_valid(_settings):
		_settings.set_menu_button_visible(false)
		_language = _settings.current_language
		_settings.language_changed.connect(_on_language_changed)
	_build_ui()
	_refresh_text()
	queue_redraw()


func _process(delta: float) -> void:
	_track_mouse_cursor()
	if not _simulation_paused:
		var scaled_delta: float = delta * float(SPEEDS[_speed_index])
		_simulation_age += scaled_delta
		if _cascade_enabled:
			_cascade_accumulator += scaled_delta
			while _cascade_accumulator >= CASCADE_PERIOD:
				_cascade_accumulator -= CASCADE_PERIOD
				_fire_cascade_step()
		for wave in _waves:
			wave["age"] += scaled_delta
			wave["extent"] = wave["age"] * WAVE_SPEED
		for index in range(_waves.size() - 1, -1, -1):
			if not bool(_waves[index].get("persistent", false)) and _waves[index]["age"] >= WAVE_LIFETIME:
				_waves.remove_at(index)
	_update_stats()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _settings_open():
		return
	if event is InputEventMouseMotion:
		_update_cursor_from_pointer(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_cursor_position = _clamp_to_arena(event.position)
		if ARENA_RECT.has_point(event.position):
			_place_resonator(_cursor_position)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("place_resonator"):
		_place_resonator(_cursor_position)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("resonator_volley"):
		_fire_volley()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dev_color_previous"):
		_select_color(wrapi(_selected_color - 1, 0, ResonanceCatalog.COLORS.size()))
	elif event.is_action_pressed("dev_color_next"):
		_select_color(wrapi(_selected_color + 1, 0, ResonanceCatalog.COLORS.size()))
	elif event.is_action_pressed("dev_remove_last"):
		_remove_last_resonator()
	elif event.is_action_pressed("dev_clear"):
		_clear_room()
	elif event.is_action_pressed("dev_toggle_simulation"):
		_toggle_simulation()
	elif event.is_action_pressed("dev_slower"):
		_change_speed(-1)
	elif event.is_action_pressed("dev_faster"):
		_change_speed(1)


func _track_mouse_cursor() -> void:
	_update_cursor_from_pointer(get_viewport().get_mouse_position())


func _update_cursor_from_pointer(pointer_position: Vector2) -> void:
	if not ARENA_RECT.has_point(pointer_position):
		return
	var next_position := _clamp_to_arena(pointer_position)
	if _cursor_position.is_equal_approx(next_position):
		return
	_cursor_position = next_position
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.010, 0.014, 0.021), true)
	draw_rect(ARENA_RECT, Color(0.020, 0.027, 0.038), true)
	draw_rect(ARENA_RECT, Color(0.42, 0.50, 0.61, 0.82), false, 2.0)
	_draw_grid()
	for wave in _waves:
		_draw_wave(wave)
	_draw_resonances()
	_draw_cursor()


func _draw_grid() -> void:
	for x in range(int(ARENA_RECT.position.x) + 32, int(ARENA_RECT.end.x), 32):
		draw_line(Vector2(x, ARENA_RECT.position.y), Vector2(x, ARENA_RECT.end.y), Color(0.30, 0.36, 0.44, 0.08), 1.0)
	for y in range(int(ARENA_RECT.position.y) + 32, int(ARENA_RECT.end.y), 32):
		draw_line(Vector2(ARENA_RECT.position.x, y), Vector2(ARENA_RECT.end.x, y), Color(0.30, 0.36, 0.44, 0.08), 1.0)


func _draw_wave(wave: Dictionary) -> void:
	var color: Color = ResonanceCatalog.color_spec(wave["color_index"])["color"]
	var points := DeveloperWaveGeometry.front_points(wave)
	if points.size() < 2:
		return
	draw_polyline(points, Color(color, 0.14), 9.0, true)
	draw_polyline(points, Color(color, 0.78), 3.0, true)
	draw_polyline(points, color.lightened(0.34), 1.0, true)


func _draw_resonances() -> void:
	var started_usec := Time.get_ticks_usec()
	_last_resonance_count = 0
	_last_pair_types.clear()
	var groups_by_type := {}
	var active_resonance_keys := {}
	for first_index in range(_waves.size()):
		var first := _waves[first_index]
		for second_index in range(first_index + 1, _waves.size()):
			var second := _waves[second_index]
			if not ResonanceCatalog.can_resonate(first["color_index"], second["color_index"]):
				continue
			var resonance := ResonanceCatalog.resonance_spec(first["color_index"], second["color_index"])
			if resonance.is_empty():
				continue
			var visible_points: Array[Vector2] = []
			for point in DeveloperWaveGeometry.intersections(first, second):
				if not ARENA_RECT.grow(-3.0).has_point(point):
					continue
				_last_resonance_count += 1
				_last_pair_types[resonance["id"]] = true
				visible_points.append(point)
			if visible_points.is_empty():
				continue
			var resonance_id: String = resonance["id"]
			var resonance_key := "%s:%d:%d" % [resonance_id, first["id"], second["id"]]
			var pair_age := minf(float(first["age"]), float(second["age"]))
			if not _resonance_birth_ages.has(resonance_key):
				_resonance_birth_ages[resonance_key] = pair_age
			active_resonance_keys[resonance_key] = true
			if not groups_by_type.has(resonance_id):
				groups_by_type[resonance_id] = []
			groups_by_type[resonance_id].append({
				"points": visible_points,
				"first": first,
				"second": second,
				"resonance": resonance,
				"resonance_key": resonance_key,
				"effect_age": maxf(0.0, pair_age - float(_resonance_birth_ages[resonance_key])),
			})
	for resonance_key in _resonance_birth_ages.keys():
		if not active_resonance_keys.has(resonance_key):
			_resonance_birth_ages.erase(resonance_key)

	var phase := Time.get_ticks_msec() * 0.001
	var drawn_global_resonances := {}
	for resonance_id in groups_by_type:
		var groups: Array = groups_by_type[resonance_id]
		if resonance_id in ["gy", "gold_gold"]:
			var global_state := _global_resonance_states.get(resonance_id, {}) as Dictionary
			if global_state.is_empty():
				global_state = {
					"resonance_id": resonance_id,
					"birth_time": _simulation_age,
					"anchor": Vector2(groups[0]["points"][0]),
					"tile_births": {},
					"pair_local_positions": {},
					"pair_sample_counts": {},
					"scheduled_pairs": {},
				}
				_global_resonance_states[resonance_id] = global_state
			for group in groups:
				group["global_state"] = global_state
				group["simulation_age"] = _simulation_age
			drawn_global_resonances[resonance_id] = true
		var first_group: Dictionary = groups[0]
		var first_wave: Dictionary = first_group["first"]
		var second_wave: Dictionary = first_group["second"]
		if first_wave["color_index"] == second_wave["color_index"]:
			DeveloperResonanceRenderer.draw_same_color(self, resonance_id, groups, ARENA_RECT, phase)
		else:
			DeveloperResonanceRenderer.draw_mixed(self, resonance_id, groups, ARENA_RECT, phase)
	for resonance_id in _global_resonance_states:
		if not drawn_global_resonances.has(resonance_id):
			DeveloperResonanceRenderer.draw_persistent_global(self, resonance_id, _global_resonance_states[resonance_id], ARENA_RECT, _simulation_age)
	_last_geometry_usec = Time.get_ticks_usec() - started_usec


func _draw_resonance_marker(point: Vector2, first: Dictionary, second: Dictionary, resonance: Dictionary) -> void:
	var color := ResonanceCatalog.resonance_color(first["color_index"], second["color_index"])
	var phase := Time.get_ticks_msec() * 0.004 + float(first["id"] + second["id"])
	var radius := 10.0 + sin(phase) * 2.0
	draw_circle(point, radius + 8.0, Color(color, 0.12))
	draw_circle(point, radius, Color(color, 0.44))
	draw_circle(point, 3.5, Color(0.97, 0.97, 1.0, 0.98))
	draw_line(point - Vector2(15, 0), point + Vector2(15, 0), Color(color, 0.82), 1.5, true)
	draw_line(point - Vector2(0, 15), point + Vector2(0, 15), Color(color, 0.82), 1.5, true)
	draw_string(ThemeDB.fallback_font, point + Vector2(-26, -18), resonance["id"].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 52.0, 11, Color(color, 0.94))


func _draw_cursor() -> void:
	var color: Color = ResonanceCatalog.color_spec(_selected_color)["color"]
	draw_circle(_cursor_position, 14.0, Color(color, 0.08))
	draw_arc(_cursor_position, 14.0, 0.0, TAU, 32, Color(color, 0.88), 2.0, true)
	draw_line(_cursor_position - Vector2(20, 0), _cursor_position + Vector2(20, 0), Color(color, 0.62), 1.0)
	draw_line(_cursor_position - Vector2(0, 20), _cursor_position + Vector2(0, 20), Color(color, 0.62), 1.0)


func _place_resonator(position: Vector2) -> void:
	if not ARENA_RECT.grow(-32.0).has_point(position):
		return
	_selected_preset = -1
	if _resonators.size() >= MAX_RESONATORS:
		var oldest: DeveloperResonator = _resonators.pop_front()
		_remove_waves_for_source(oldest.sequence_id)
		oldest.queue_free()
	var angle := (position - ARENA_RECT.get_center()).angle()
	if position.distance_to(ARENA_RECT.get_center()) < 24.0:
		angle = float(_next_source_id) * 0.91
	_spawn_resonator(_selected_color, position, angle)
	_refresh_preset_menu()


func _spawn_resonator(color_index: int, position: Vector2, angle: float) -> void:
	var source := DeveloperResonator.new()
	source.position = position
	source.configure(color_index, _next_source_id, angle)
	_next_source_id += 1
	add_child(source)
	move_child(source, 0)
	_resonators.append(source)
	_update_stats()


func _load_preset(index: int) -> void:
	if index < 0 or index >= PRESETS.size():
		return
	_clear_room()
	_selected_preset = index
	var preset: Dictionary = PRESETS[index]
	var pair: Vector2i = preset["pair"]
	var colors := [pair.x, pair.y]
	for source_index in range(2):
		var normalized: Vector2 = preset["positions"][source_index]
		var position := ARENA_RECT.position + normalized * ARENA_RECT.size
		_spawn_resonator(colors[source_index], position, float(preset["angles"][source_index]))
	_selected_color = pair.y
	for button_index in range(_color_buttons.size()):
		_color_buttons[button_index].button_pressed = button_index == _selected_color
	_cascade_accumulator = CASCADE_PERIOD if _cascade_enabled else 0.0
	_refresh_text()
	queue_redraw()


func _fire_volley() -> void:
	_current_volley_index = _next_volley_index
	_next_volley_index += 1
	for source in _resonators:
		source.trigger()
		_spawn_wave(source, "short", false)
	_trim_waves()


func _fire_cascade_step() -> void:
	_current_volley_index = _next_volley_index
	_next_volley_index += 1
	for source in _resonators:
		source.trigger()
		var spec := ResonanceCatalog.color_spec(source.color_index)
		if spec["geometry"] == "spiral":
			if not _has_long_spiral(source.sequence_id):
				_spawn_wave(source, "long", true)
		else:
			_spawn_wave(source, "short", false)
	_trim_waves()


func _spawn_wave(source: DeveloperResonator, spiral_mode: String, persistent: bool) -> void:
	var spec := ResonanceCatalog.color_spec(source.color_index)
	_waves.append({
		"id": _next_wave_id,
		"volley_index": _current_volley_index,
		"source_id": source.sequence_id,
		"color_index": source.color_index,
		"geometry": spec["geometry"],
		"origin": source.position,
		"angle": source.front_angle,
		"spiral_mode": spiral_mode,
		"spiral_chirality": 1.0 if cos(source.front_angle) >= 0.0 else -1.0,
		"spiral_stop_age": WAVE_LIFETIME - DeveloperWaveGeometry.SPIRAL_SHORT_DRAIN_TIME if spec["geometry"] == "spiral" and spiral_mode == "short" else INF,
		"persistent": persistent,
		"age": 0.0,
		"extent": 0.0,
	})
	_next_wave_id += 1


func _has_long_spiral(source_id: int) -> bool:
	for wave in _waves:
		if wave["source_id"] == source_id and wave.get("spiral_mode", "") == "long":
			return true
	return false


func _trim_waves() -> void:
	while _waves.size() > MAX_WAVES:
		var removable := -1
		for index in range(_waves.size()):
			if not bool(_waves[index].get("persistent", false)):
				removable = index
				break
		if removable >= 0:
			_waves.remove_at(removable)
		else:
			break


func _remove_last_resonator() -> void:
	if _resonators.is_empty():
		return
	var source: DeveloperResonator = _resonators.pop_back()
	_remove_waves_for_source(source.sequence_id)
	source.queue_free()
	_update_stats()


func _remove_waves_for_source(source_id: int) -> void:
	for index in range(_waves.size() - 1, -1, -1):
		if _waves[index]["source_id"] == source_id:
			_waves.remove_at(index)


func _clear_room() -> void:
	for source in _resonators:
		source.queue_free()
	_resonators.clear()
	_waves.clear()
	_resonance_birth_ages.clear()
	_global_resonance_states.clear()
	_simulation_age = 0.0
	_next_volley_index = 1
	_current_volley_index = 0
	_update_stats()


func _select_color(index: int) -> void:
	_selected_color = clampi(index, 0, ResonanceCatalog.COLORS.size() - 1)
	for button_index in range(_color_buttons.size()):
		_color_buttons[button_index].button_pressed = button_index == _selected_color
	_refresh_text()
	queue_redraw()


func _toggle_simulation() -> void:
	_simulation_paused = not _simulation_paused
	_refresh_text()


func _toggle_cascade() -> void:
	_cascade_enabled = not _cascade_enabled
	_cascade_accumulator = CASCADE_PERIOD if _cascade_enabled else 0.0
	if not _cascade_enabled:
		for index in range(_waves.size() - 1, -1, -1):
			if bool(_waves[index].get("persistent", false)):
				_waves.remove_at(index)
	_refresh_text()


func _change_speed(direction: int) -> void:
	_speed_index = clampi(_speed_index + direction, 0, SPEEDS.size() - 1)
	_refresh_text()


func _build_ui() -> void:
	var side := Panel.new()
	side.name = "DeveloperPanel"
	side.position = Vector2(12, 12)
	side.size = Vector2(226, 696)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.022, 0.028, 0.039, 0.98)
	panel_style.border_color = Color(0.40, 0.47, 0.58, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(9)
	side.add_theme_stylebox_override("panel", panel_style)
	add_child(side)

	_title_label = _label(Vector2(14, 12), Vector2(198, 52), 19)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_title_label)
	_selected_label = _label(Vector2(14, 62), Vector2(198, 48), 16)
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_selected_label)

	for index in range(ResonanceCatalog.COLORS.size()):
		var spec := ResonanceCatalog.color_spec(index)
		var button := Button.new()
		button.name = "%sColorButton" % spec["id"]
		button.position = Vector2(18, 114 + index * 48)
		button.size = Vector2(190, 42)
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 16)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(spec["color"], 0.20)
		style.border_color = Color(spec["color"], 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override("normal", style)
		button.pressed.connect(_select_color.bind(index))
		side.add_child(button)
		_color_buttons.append(button)

	_count_label = _label(Vector2(14, 456), Vector2(198, 30), 16)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_count_label)
	_stats_label = _label(Vector2(14, 486), Vector2(198, 48), 14)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_stats_label)

	_cascade_button = _button(Vector2(18, 538), Vector2(190, 38), _toggle_cascade)
	_cascade_button.name = "ContinuousCascadeButton"
	side.add_child(_cascade_button)
	_pause_button = _button(Vector2(18, 582), Vector2(92, 38), _toggle_simulation)
	_pause_button.name = "PauseSimulationButton"
	side.add_child(_pause_button)
	_speed_button = _button(Vector2(116, 582), Vector2(92, 38), _change_speed.bind(1))
	_speed_button.name = "SimulationSpeedButton"
	side.add_child(_speed_button)
	var clear := _button(Vector2(18, 626), Vector2(190, 32), _clear_room)
	clear.name = "ClearButton"
	clear.text = "ОЧИСТИТЬ"
	side.add_child(clear)
	var settings_button := _button(Vector2(18, 664), Vector2(92, 32), _open_settings)
	settings_button.name = "SettingsButton"
	settings_button.text = "⚙"
	side.add_child(settings_button)
	var back := _button(Vector2(116, 664), Vector2(92, 32), _return_to_menu)
	back.name = "BackButton"
	back.text = "←"
	side.add_child(back)

	_preset_menu = MenuButton.new()
	_preset_menu.name = "ResonancePresetMenu"
	_preset_menu.position = Vector2(260, 18)
	_preset_menu.size = Vector2(190, 42)
	_preset_menu.add_theme_font_size_override("font_size", 14)
	_preset_menu.get_popup().id_pressed.connect(_load_preset)
	add_child(_preset_menu)
	_help_label = _label(Vector2(458, 18), Vector2(772, 42), 14)
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_help_label)
	_select_color(0)


func _label(position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = label_size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(position: Vector2, button_size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	return button


func _refresh_text() -> void:
	if not is_instance_valid(_title_label):
		return
	var russian := _language == "ru"
	var spec := ResonanceCatalog.color_spec(_selected_color)
	_title_label.text = "КОМНАТА\nРАЗРАБОТЧИКА" if russian else "DEVELOPER\nROOM"
	_selected_label.text = "%s · %s" % [spec["ru"] if russian else spec["en"], spec["geometry"]]
	for index in range(_color_buttons.size()):
		var color_spec := ResonanceCatalog.color_spec(index)
		_color_buttons[index].text = "%s  %s" % [color_spec["symbol"], color_spec["ru"] if russian else color_spec["en"]]
	_pause_button.text = "ПУСК" if _simulation_paused and russian else "RUN" if _simulation_paused else "ПАУЗА" if russian else "PAUSE"
	_speed_button.text = "×%.2f" % float(SPEEDS[_speed_index])
	_cascade_button.text = ("КАСКАД: ВКЛ" if _cascade_enabled else "КАСКАД: ВЫКЛ") if russian else ("CASCADE: ON" if _cascade_enabled else "CASCADE: OFF")
	_refresh_preset_menu()
	_help_label.text = (
		"E — поставить · ПКМ — залп · Q/F — цвет · X — удалить · C — очистить · T — пауза · −/+ — скорость"
		if russian
		else "E — place · RMB — volley · Q/F — color · X — remove · C — clear · T — pause · −/+ — speed"
	)
	_update_stats()


func _refresh_preset_menu() -> void:
	if not is_instance_valid(_preset_menu):
		return
	var popup := _preset_menu.get_popup()
	popup.clear()
	for index in range(PRESETS.size()):
		popup.add_item(_preset_label(index), index)
	_preset_menu.text = _preset_label(_selected_preset) if _selected_preset >= 0 else ("ПРЕСЕТЫ (13)" if _language == "ru" else "PRESETS (13)")


func _preset_label(index: int) -> String:
	var preset: Dictionary = PRESETS[index]
	var pair: Vector2i = preset["pair"]
	var first := ResonanceCatalog.color_spec(pair.x)
	var second := ResonanceCatalog.color_spec(pair.y)
	var resonance := ResonanceCatalog.resonance_spec(pair.x, pair.y)
	var name: String = resonance["ru"] if _language == "ru" else resonance["en"]
	return "%s/%s · %s" % [first["symbol"], second["symbol"], name]


func _update_stats() -> void:
	if not is_instance_valid(_count_label):
		return
	_count_label.text = ("РЕЗОНАТОРЫ %d/%d" if _language == "ru" else "RESONATORS %d/%d") % [_resonators.size(), MAX_RESONATORS]
	var active_types: Array[String] = []
	for resonance_id in _last_pair_types:
		active_types.append(str(resonance_id).to_upper())
	active_types.sort()
	var type_text := ",".join(active_types) if not active_types.is_empty() else "—"
	_stats_label.text = (
		("Волны %d · Узлы %d\n%s · %.2f ms" if _language == "ru" else "Waves %d · Nodes %d\n%s · %.2f ms")
		% [_waves.size(), _last_resonance_count, type_text, float(_last_geometry_usec) / 1000.0]
	)


func _clamp_to_arena(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, ARENA_RECT.position.x, ARENA_RECT.end.x), clampf(point.y, ARENA_RECT.position.y, ARENA_RECT.end.y))


func _settings_open() -> bool:
	return is_instance_valid(_settings) and _settings.is_open()


func _open_settings() -> void:
	if is_instance_valid(_settings):
		_settings.open_settings()


func _on_language_changed(language: String) -> void:
	_language = language
	_refresh_text()


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
