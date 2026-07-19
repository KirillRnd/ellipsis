class_name SettingsMenu
extends CanvasLayer

signal language_changed(language: String)


class InlineOptionSelector:
	extends Control

	signal item_selected(index: int)
	signal popup_opened(selector)

	var selected := -1
	var item_count: int:
		get:
			return _items.size()

	var _items: Array[String] = []
	var _main_button: Button
	var _popup: Panel


	func _ready() -> void:
		clip_contents = false
		_main_button = Button.new()
		_main_button.name = "CurrentValue"
		_main_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_main_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_main_button.pressed.connect(_toggle_popup)
		add_child(_main_button)

		_popup = Panel.new()
		_popup.name = "InlinePopup"
		_popup.position = Vector2(0.0, size.y + 4.0)
		_popup.size = Vector2(size.x, 4.0)
		_popup.z_index = 100
		_popup.visible = false
		add_child(_popup)


	func add_item(text: String) -> void:
		var index := _items.size()
		_items.append(text)
		var item_button := Button.new()
		item_button.name = "Item%d" % index
		item_button.text = text
		item_button.position = Vector2(2.0, 2.0 + index * 40.0)
		item_button.size = Vector2(maxf(0.0, size.x - 4.0), 40.0)
		item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_button.pressed.connect(_select_from_popup.bind(index))
		_popup.add_child(item_button)
		_popup.size = Vector2(size.x, 4.0 + _items.size() * 40.0)
		if selected < 0:
			select(0)


	func clear() -> void:
		_items.clear()
		selected = -1
		_main_button.text = ""
		for child in _popup.get_children():
			_popup.remove_child(child)
			child.queue_free()
		_popup.size = Vector2(size.x, 4.0)
		collapse()


	func select(index: int) -> void:
		if index < 0 or index >= _items.size():
			return
		selected = index
		_main_button.text = "%s  ▾" % _items[index]


	func collapse() -> void:
		if is_instance_valid(_popup):
			_popup.visible = false


	func _toggle_popup() -> void:
		_popup.visible = not _popup.visible
		if _popup.visible:
			popup_opened.emit(self)


	func _select_from_popup(index: int) -> void:
		select(index)
		collapse()
		item_selected.emit(index)

const SETTINGS_PATH := "user://settings.cfg"
const TOGGLE_ACTION := &"toggle_pause_menu"
const RESUME_DURATION := 1.0
const DEFAULT_LANGUAGE := "ru"
const SUPPORTED_LANGUAGES := ["ru", "en"]

var current_language := DEFAULT_LANGUAGE
var _sfx_volume := 100.0
var _music_volume := 100.0
var _fullscreen := false
var _sfx_base_db := 0.0
var _music_base_db := 0.0
var _tree_was_paused := false
var _time_scale_before_pause := 1.0
var _is_open := false
var _resume_tween: Tween

var _menu_button: Button
var _modal_root: Control
var _panel: Panel
var _close_button: Button
var _title_label: Label
var _language_label: Label
var _language_option: InlineOptionSelector
var _screen_label: Label
var _screen_option: InlineOptionSelector
var _sfx_label: Label
var _sfx_slider: HSlider
var _sfx_value_label: Label
var _music_label: Label
var _music_slider: HSlider
var _music_value_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	_capture_editor_bus_levels()
	_load_settings()
	_build_ui()
	_apply_saved_settings()
	_refresh_text()


func _exit_tree() -> void:
	if is_instance_valid(_resume_tween):
		_resume_tween.kill()
	if _is_open and not _tree_was_paused and is_instance_valid(get_tree()):
		get_tree().paused = false
		Engine.time_scale = _time_scale_before_pause


func _input(event: InputEvent) -> void:
	if is_menu_button_pointer_event(event):
		get_viewport().set_input_as_handled()
		open_settings()
		return
	if not event.is_action_pressed(TOGGLE_ACTION):
		return
	if event is InputEventKey and event.echo:
		return
	get_viewport().set_input_as_handled()
	if _is_open:
		close_settings()
	else:
		open_settings()


func is_open() -> bool:
	return _is_open


func is_menu_button_pointer_event(event: InputEvent) -> bool:
	if _is_open or not is_instance_valid(_menu_button) or not _menu_button.visible:
		return false
	var pointer_position := Vector2.ZERO
	if event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return false
		pointer_position = event.position
	elif event is InputEventScreenTouch:
		if not event.pressed:
			return false
		pointer_position = event.position
	else:
		return false
	return _menu_button.get_global_rect().has_point(pointer_position)


func open_settings() -> void:
	if _is_open:
		return
	if is_instance_valid(_resume_tween):
		_resume_tween.kill()
		_resume_tween = null
		Engine.time_scale = _time_scale_before_pause
	_tree_was_paused = get_tree().paused
	_time_scale_before_pause = Engine.time_scale
	get_tree().paused = true
	_is_open = true
	_modal_root.visible = true
	_menu_button.visible = false
	_close_button.grab_focus()


func close_settings() -> void:
	if not _is_open:
		return
	_is_open = false
	_language_option.collapse()
	_screen_option.collapse()
	_modal_root.visible = false
	_menu_button.visible = true
	_menu_button.grab_focus()
	if _tree_was_paused:
		get_tree().paused = true
		return
	_resume_gameplay()


func toggle_settings() -> void:
	if _is_open:
		close_settings()
	else:
		open_settings()


func set_language(language: String) -> void:
	var normalized := language.to_lower()
	if normalized not in SUPPORTED_LANGUAGES:
		normalized = DEFAULT_LANGUAGE
	var changed := current_language != normalized
	current_language = normalized
	TranslationServer.set_locale(current_language)
	_select_language_option()
	_refresh_text()
	_save_settings()
	if changed:
		language_changed.emit(current_language)


func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	if DisplayServer.get_name().to_lower() != "headless":
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
		)
	_select_screen_option()
	_save_settings()


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 100.0)
	_set_bus_level(&"SFX", _sfx_base_db, _sfx_volume)
	if is_instance_valid(_sfx_slider):
		_sfx_slider.set_value_no_signal(_sfx_volume)
	if is_instance_valid(_sfx_value_label):
		_sfx_value_label.text = "%d / 100" % roundi(_sfx_volume)
	_save_settings()


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 100.0)
	_set_bus_level(&"Music", _music_base_db, _music_volume)
	if is_instance_valid(_music_slider):
		_music_slider.set_value_no_signal(_music_volume)
	if is_instance_valid(_music_value_label):
		_music_value_label.text = "%d / 100" % roundi(_music_volume)
	_save_settings()


func get_sfx_volume() -> float:
	return _sfx_volume


func get_music_volume() -> float:
	return _music_volume


func is_fullscreen() -> bool:
	return _fullscreen


func _resume_gameplay() -> void:
	var target_scale := maxf(_time_scale_before_pause, 0.001)
	Engine.time_scale = maxf(target_scale * 0.01, 0.001)
	get_tree().paused = false
	_resume_tween = create_tween()
	_resume_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_resume_tween.set_ignore_time_scale(true)
	_resume_tween.tween_method(
		_set_engine_time_scale,
		Engine.time_scale,
		target_scale,
		RESUME_DURATION,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_resume_tween.finished.connect(_on_resume_finished)


func _set_engine_time_scale(value: float) -> void:
	Engine.time_scale = value


func _on_resume_finished() -> void:
	Engine.time_scale = _time_scale_before_pause
	_resume_tween = null


func _capture_editor_bus_levels() -> void:
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	if sfx_index >= 0:
		_sfx_base_db = AudioServer.get_bus_volume_db(sfx_index)
	var music_index := AudioServer.get_bus_index(&"Music")
	if music_index >= 0:
		_music_base_db = AudioServer.get_bus_volume_db(music_index)


func _set_bus_level(bus_name: StringName, base_db: float, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized := clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.0001)
	if normalized > 0.0001:
		AudioServer.set_bus_volume_db(bus_index, base_db + linear_to_db(normalized))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var loaded_language := str(config.get_value("general", "language", DEFAULT_LANGUAGE)).to_lower()
	current_language = loaded_language if loaded_language in SUPPORTED_LANGUAGES else DEFAULT_LANGUAGE
	_fullscreen = bool(config.get_value("display", "fullscreen", false))
	_sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 100.0)), 0.0, 100.0)
	_music_volume = clampf(float(config.get_value("audio", "music_volume", 100.0)), 0.0, 100.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", current_language)
	config.set_value("display", "fullscreen", _fullscreen)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "music_volume", _music_volume)
	config.save(SETTINGS_PATH)


func _apply_saved_settings() -> void:
	TranslationServer.set_locale(current_language)
	set_fullscreen(_fullscreen)
	set_sfx_volume(_sfx_volume)
	set_music_volume(_music_volume)
	_select_language_option()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.anchor_left = 1.0
	_menu_button.anchor_right = 1.0
	_menu_button.offset_left = -150.0
	_menu_button.offset_top = 16.0
	_menu_button.offset_right = -16.0
	_menu_button.offset_bottom = 62.0
	_menu_button.focus_mode = Control.FOCUS_ALL
	_menu_button.add_theme_font_size_override("font_size", 18)
	_menu_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.025, 0.03, 0.04, 0.92)))
	_menu_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.10, 0.12, 0.15, 0.98)))
	_menu_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.16, 0.18, 0.22, 1.0)))
	_menu_button.pressed.connect(open_settings)
	root.add_child(_menu_button)

	_modal_root = Control.new()
	_modal_root.name = "SettingsModal"
	_modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.visible = false
	root.add_child(_modal_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.008, 0.014, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.add_child(shade)

	_panel = Panel.new()
	_panel.name = "SettingsPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -300.0
	_panel.offset_top = -245.0
	_panel.offset_right = 300.0
	_panel.offset_bottom = 245.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.03, 0.04, 0.99)
	panel_style.border_color = Color(0.58, 0.64, 0.70, 0.96)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	panel_style.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", panel_style)
	_modal_root.add_child(_panel)

	_title_label = _make_label(Vector2(38, 28), Vector2(524, 44), 28)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	_panel.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "×"
	_close_button.position = Vector2(536, 18)
	_close_button.size = Vector2(46, 46)
	_close_button.tooltip_text = "Esc"
	_close_button.add_theme_font_size_override("font_size", 28)
	_close_button.flat = true
	_close_button.pressed.connect(close_settings)
	_panel.add_child(_close_button)

	_language_label = _make_label(Vector2(54, 100), Vector2(220, 38), 20)
	_panel.add_child(_language_label)
	_language_option = InlineOptionSelector.new()
	_language_option.name = "LanguageOption"
	_language_option.position = Vector2(306, 98)
	_language_option.size = Vector2(238, 42)
	_panel.add_child(_language_option)
	_language_option.add_item("Русский")
	_language_option.add_item("English")
	_language_option.item_selected.connect(_on_language_selected)
	_language_option.popup_opened.connect(_on_selector_popup_opened)

	_screen_label = _make_label(Vector2(54, 164), Vector2(220, 38), 20)
	_panel.add_child(_screen_label)
	_screen_option = InlineOptionSelector.new()
	_screen_option.name = "ScreenOption"
	_screen_option.position = Vector2(306, 162)
	_screen_option.size = Vector2(238, 42)
	_panel.add_child(_screen_option)
	_screen_option.item_selected.connect(_on_screen_mode_selected)
	_screen_option.popup_opened.connect(_on_selector_popup_opened)

	_sfx_label = _make_label(Vector2(54, 236), Vector2(220, 34), 20)
	_panel.add_child(_sfx_label)
	_sfx_slider = _make_slider(Vector2(54, 274))
	_sfx_slider.name = "SfxSlider"
	_sfx_slider.value_changed.connect(set_sfx_volume)
	_panel.add_child(_sfx_slider)
	_sfx_value_label = _make_label(Vector2(450, 267), Vector2(94, 34), 17)
	_sfx_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_sfx_value_label)

	_music_label = _make_label(Vector2(54, 326), Vector2(220, 34), 20)
	_panel.add_child(_music_label)
	_music_slider = _make_slider(Vector2(54, 364))
	_music_slider.name = "MusicSlider"
	_music_slider.value_changed.connect(set_music_volume)
	_panel.add_child(_music_slider)
	_music_value_label = _make_label(Vector2(450, 357), Vector2(94, 34), 17)
	_music_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_music_value_label)

func _make_label(position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_slider(position: Vector2) -> HSlider:
	var slider := HSlider.new()
	slider.position = position
	slider.size = Vector2(380, 30)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.tick_count = 11
	slider.ticks_on_borders = true
	return slider


func _make_button_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.48, 0.54, 0.60, 0.95)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _refresh_text() -> void:
	if not is_instance_valid(_title_label):
		return
	var is_russian := current_language == "ru"
	_title_label.text = "НАСТРОЙКИ" if is_russian else "SETTINGS"
	_menu_button.text = "☰  МЕНЮ" if is_russian else "☰  MENU"
	_menu_button.tooltip_text = "Меню и пауза (Esc)" if is_russian else "Menu and pause (Esc)"
	_language_label.text = "Язык" if is_russian else "Language"
	_screen_label.text = "Режим экрана" if is_russian else "Screen mode"
	_sfx_label.text = "Громкость звуков" if is_russian else "SFX volume"
	_music_label.text = "Громкость музыки" if is_russian else "Music volume"
	var selected_screen := _screen_option.selected if is_instance_valid(_screen_option) else 0
	if is_instance_valid(_screen_option):
		_screen_option.clear()
		_screen_option.add_item("В окне" if is_russian else "Windowed")
		_screen_option.add_item("Во весь экран" if is_russian else "Fullscreen")
		_screen_option.select(clampi(selected_screen, 0, 1))
	set_sfx_volume(_sfx_volume)
	set_music_volume(_music_volume)
	_select_language_option()
	_select_screen_option()


func _select_language_option() -> void:
	if is_instance_valid(_language_option):
		_language_option.select(0 if current_language == "ru" else 1)


func _select_screen_option() -> void:
	if is_instance_valid(_screen_option) and _screen_option.item_count >= 2:
		_screen_option.select(1 if _fullscreen else 0)


func _on_language_selected(index: int) -> void:
	set_language("ru" if index == 0 else "en")


func _on_screen_mode_selected(index: int) -> void:
	set_fullscreen(index == 1)


func _on_selector_popup_opened(selector) -> void:
	if selector != _language_option:
		_language_option.collapse()
	if selector != _screen_option:
		_screen_option.collapse()
