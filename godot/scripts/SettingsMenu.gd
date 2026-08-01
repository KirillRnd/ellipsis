class_name SettingsMenu
extends CanvasLayer

signal language_changed(language: String)
signal bindings_changed


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
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"dash",
	&"crossbar",
	&"place_resonator",
	&"resonator_volley",
	&"cursor_left",
	&"cursor_right",
	&"cursor_up",
	&"cursor_down",
	&"toggle_pause_menu",
]
const ACTION_TEXT := {
	"move_left": {"ru": "Движение влево", "en": "Move left"},
	"move_right": {"ru": "Движение вправо", "en": "Move right"},
	"move_up": {"ru": "Движение вверх", "en": "Move up"},
	"move_down": {"ru": "Движение вниз", "en": "Move down"},
	"dash": {"ru": "Рывок", "en": "Dash"},
	"crossbar": {"ru": "Ковырялка", "en": "Crossbar"},
	"place_resonator": {"ru": "Поставить Резонатор", "en": "Place Resonator"},
	"resonator_volley": {"ru": "Залп Резонаторов", "en": "Resonator volley"},
	"cursor_left": {"ru": "Курсор влево", "en": "Cursor left"},
	"cursor_right": {"ru": "Курсор вправо", "en": "Cursor right"},
	"cursor_up": {"ru": "Курсор вверх", "en": "Cursor up"},
	"cursor_down": {"ru": "Курсор вниз", "en": "Cursor down"},
	"toggle_pause_menu": {"ru": "Меню / пауза", "en": "Menu / pause"},
}

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
var _menu_button_enabled := true
var _default_input_events := {}
var _rebinding_action: StringName = &""
var _pending_input_event: InputEvent
var _pending_conflicts: Array[StringName] = []

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
var _bindings_button: Button
var _bindings_panel: Panel
var _bindings_title: Label
var _bindings_help: Label
var _binding_buttons := {}
var _binding_conflict_label: Label
var _binding_confirm_button: Button
var _binding_cancel_button: Button
var _binding_reset_button: Button
var _binding_back_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	_capture_editor_bus_levels()
	_capture_default_input_events()
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
	if not _rebinding_action.is_empty():
		if _try_capture_binding_event(event):
			get_viewport().set_input_as_handled()
		return
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
	_panel.visible = true
	_bindings_panel.visible = false
	_menu_button.visible = false
	_close_button.grab_focus()


func set_menu_button_visible(enabled: bool) -> void:
	_menu_button_enabled = enabled
	if is_instance_valid(_menu_button) and not _is_open:
		_menu_button.visible = enabled


func close_settings() -> void:
	if not _is_open:
		return
	_is_open = false
	_cancel_pending_binding()
	_language_option.collapse()
	_screen_option.collapse()
	_close_button.release_focus()
	_modal_root.visible = false
	_menu_button.visible = _menu_button_enabled
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


func get_action_binding_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		labels.append(_event_text(event))
	return " / ".join(labels) if not labels.is_empty() else "—"


func get_action_short_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	return _short_event_text(events[0])


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
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action) or not config.has_section_key("input", str(action)):
			continue
		var stored_events = config.get_value("input", str(action), [])
		if stored_events is Array:
			InputMap.action_erase_events(action)
			for event in stored_events:
				if event is InputEvent:
					InputMap.action_add_event(action, event)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", current_language)
	config.set_value("display", "fullscreen", _fullscreen)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "music_volume", _music_volume)
	for action in REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			config.set_value("input", str(action), InputMap.action_get_events(action))
	config.save(SETTINGS_PATH)


func _capture_default_input_events() -> void:
	_default_input_events.clear()
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var copies: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			copies.append(event.duplicate(true))
		_default_input_events[action] = copies


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
	_menu_button.focus_mode = Control.FOCUS_NONE
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

	_bindings_button = Button.new()
	_bindings_button.name = "BindingsButton"
	_bindings_button.position = Vector2(54, 420)
	_bindings_button.size = Vector2(490, 46)
	_bindings_button.add_theme_font_size_override("font_size", 19)
	_bindings_button.pressed.connect(_open_bindings)
	_panel.add_child(_bindings_button)

	_build_bindings_ui()


func _build_bindings_ui() -> void:
	_bindings_panel = Panel.new()
	_bindings_panel.name = "BindingsPanel"
	_bindings_panel.anchor_left = 0.5
	_bindings_panel.anchor_top = 0.5
	_bindings_panel.anchor_right = 0.5
	_bindings_panel.anchor_bottom = 0.5
	_bindings_panel.offset_left = -430.0
	_bindings_panel.offset_top = -320.0
	_bindings_panel.offset_right = 430.0
	_bindings_panel.offset_bottom = 320.0
	_bindings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_bindings_panel.add_theme_stylebox_override("panel", _make_button_style(Color(0.025, 0.03, 0.04, 0.99)))
	_bindings_panel.visible = false
	_modal_root.add_child(_bindings_panel)

	_bindings_title = _make_label(Vector2(42, 22), Vector2(776, 42), 28)
	_bindings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bindings_panel.add_child(_bindings_title)
	_bindings_help = _make_label(Vector2(42, 62), Vector2(776, 30), 16)
	_bindings_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bindings_help.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	_bindings_panel.add_child(_bindings_help)

	var scroll := ScrollContainer.new()
	scroll.name = "BindingsScroll"
	scroll.position = Vector2(36, 104)
	scroll.size = Vector2(788, 390)
	_bindings_panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "BindingsList"
	list.custom_minimum_size.x = 764.0
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)

	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 42.0
		list.add_child(row)
		var label := Label.new()
		label.name = "%sLabel" % action
		label.custom_minimum_size.x = 300.0
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		row.add_child(label)
		var button := Button.new()
		button.name = "%sBinding" % action
		button.custom_minimum_size = Vector2(444.0, 40.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_begin_rebind.bind(action))
		row.add_child(button)
		_binding_buttons[action] = button

	_binding_conflict_label = _make_label(Vector2(42, 502), Vector2(776, 30), 15)
	_binding_conflict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_binding_conflict_label.add_theme_color_override("font_color", Color(1.0, 0.70, 0.38))
	_bindings_panel.add_child(_binding_conflict_label)

	_binding_confirm_button = Button.new()
	_binding_confirm_button.name = "ConfirmConflictButton"
	_binding_confirm_button.position = Vector2(252, 536)
	_binding_confirm_button.size = Vector2(170, 42)
	_binding_confirm_button.pressed.connect(_confirm_conflicting_binding)
	_bindings_panel.add_child(_binding_confirm_button)
	_binding_cancel_button = Button.new()
	_binding_cancel_button.name = "CancelBindingButton"
	_binding_cancel_button.position = Vector2(438, 536)
	_binding_cancel_button.size = Vector2(170, 42)
	_binding_cancel_button.pressed.connect(_cancel_pending_binding)
	_bindings_panel.add_child(_binding_cancel_button)

	_binding_reset_button = Button.new()
	_binding_reset_button.name = "ResetBindingsButton"
	_binding_reset_button.position = Vector2(42, 584)
	_binding_reset_button.size = Vector2(300, 42)
	_binding_reset_button.pressed.connect(_reset_bindings)
	_bindings_panel.add_child(_binding_reset_button)
	_binding_back_button = Button.new()
	_binding_back_button.name = "BindingsBackButton"
	_binding_back_button.position = Vector2(518, 584)
	_binding_back_button.size = Vector2(300, 42)
	_binding_back_button.pressed.connect(_return_to_general_settings)
	_bindings_panel.add_child(_binding_back_button)
	_set_conflict_controls_visible(false)

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


func _open_bindings() -> void:
	_cancel_pending_binding()
	_panel.visible = false
	_bindings_panel.visible = true
	_refresh_binding_rows()
	if not _binding_buttons.is_empty():
		var first_button = _binding_buttons.values()[0]
		if is_instance_valid(first_button):
			first_button.grab_focus()


func _return_to_general_settings() -> void:
	_cancel_pending_binding()
	_bindings_panel.visible = false
	_panel.visible = true
	_bindings_button.grab_focus()


func _begin_rebind(action: StringName) -> void:
	_rebinding_action = action
	_pending_input_event = null
	_pending_conflicts.clear()
	_set_conflict_controls_visible(false)
	_refresh_binding_rows()


func _try_capture_binding_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return false
		if event.keycode == KEY_ESCAPE:
			_cancel_pending_binding()
			return true
	elif event is InputEventMouseButton:
		if not event.pressed:
			return false
	elif event is InputEventJoypadButton:
		if not event.pressed:
			return false
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.6:
			return false
	else:
		return false

	_pending_input_event = event.duplicate(true)
	_pending_conflicts = _find_binding_conflicts(_rebinding_action, _pending_input_event)
	if _pending_conflicts.is_empty():
		_apply_pending_binding(false)
	else:
		_set_conflict_controls_visible(true)
		_refresh_binding_rows()
	return true


func _find_binding_conflicts(target_action: StringName, event: InputEvent) -> Array[StringName]:
	var conflicts: Array[StringName] = []
	for action in REBINDABLE_ACTIONS:
		if action == target_action or not InputMap.has_action(action):
			continue
		for existing in InputMap.action_get_events(action):
			if existing.is_match(event):
				conflicts.append(action)
				break
	return conflicts


func _confirm_conflicting_binding() -> void:
	_apply_pending_binding(true)


func _apply_pending_binding(remove_conflicts: bool) -> void:
	if _rebinding_action.is_empty() or not is_instance_valid(_pending_input_event):
		return
	if remove_conflicts:
		for action in _pending_conflicts:
			for existing in InputMap.action_get_events(action):
				if existing.is_match(_pending_input_event):
					InputMap.action_erase_event(action, existing)
	InputMap.action_erase_events(_rebinding_action)
	InputMap.action_add_event(_rebinding_action, _pending_input_event)
	_rebinding_action = &""
	_pending_input_event = null
	_pending_conflicts.clear()
	_set_conflict_controls_visible(false)
	_save_settings()
	_refresh_binding_rows()
	bindings_changed.emit()


func _cancel_pending_binding() -> void:
	_rebinding_action = &""
	_pending_input_event = null
	_pending_conflicts.clear()
	_set_conflict_controls_visible(false)
	_refresh_binding_rows()


func _reset_bindings() -> void:
	_cancel_pending_binding()
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event in _default_input_events.get(action, []):
			InputMap.action_add_event(action, event.duplicate(true))
	_save_settings()
	_refresh_binding_rows()
	bindings_changed.emit()


func _set_conflict_controls_visible(visible: bool) -> void:
	if is_instance_valid(_binding_confirm_button):
		_binding_confirm_button.visible = visible
	if is_instance_valid(_binding_cancel_button):
		_binding_cancel_button.visible = visible
	if is_instance_valid(_binding_conflict_label) and not visible:
		_binding_conflict_label.text = ""


func _refresh_binding_rows() -> void:
	if not is_instance_valid(_bindings_panel):
		return
	for action in _binding_buttons:
		var button: Button = _binding_buttons[action]
		var label := button.get_parent().get_child(0) as Label
		label.text = ACTION_TEXT.get(str(action), {current_language: str(action)}).get(current_language, str(action))
		if action == _rebinding_action:
			button.text = "… " + ("НАЖМИТЕ КЛАВИШУ" if current_language == "ru" else "PRESS AN INPUT")
		else:
			button.text = get_action_binding_text(action)

	if not _pending_conflicts.is_empty():
		var names: Array[String] = []
		for action in _pending_conflicts:
			names.append(ACTION_TEXT.get(str(action), {current_language: str(action)}).get(current_language, str(action)))
		_binding_conflict_label.text = (
			"Уже используется: %s" % ", ".join(names)
			if current_language == "ru"
			else "Already used by: %s" % ", ".join(names)
		)


func _event_text(event: InputEvent) -> String:
	var result := event.as_text()
	result = result.replace(" (Physical)", "")
	return result


func _short_event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return OS.get_keycode_string(code).to_upper()
	if event is InputEventMouseButton:
		var mouse_names := {
			MOUSE_BUTTON_LEFT: "LMB",
			MOUSE_BUTTON_RIGHT: "RMB",
			MOUSE_BUTTON_MIDDLE: "MMB",
			MOUSE_BUTTON_WHEEL_UP: "MW↑",
			MOUSE_BUTTON_WHEEL_DOWN: "MW↓",
		}
		return mouse_names.get(event.button_index, "M%d" % event.button_index)
	if event is InputEventJoypadButton:
		return "J%d" % event.button_index
	if event is InputEventJoypadMotion:
		return "J%d%s" % [event.axis, "+" if event.axis_value > 0.0 else "−"]
	return event.as_text()


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
	_bindings_button.text = "ПЕРЕНАЗНАЧИТЬ УПРАВЛЕНИЕ" if is_russian else "REMAP CONTROLS"
	_bindings_title.text = "УПРАВЛЕНИЕ" if is_russian else "CONTROLS"
	_bindings_help.text = "Выберите действие, затем нажмите новый ввод" if is_russian else "Choose an action, then press a new input"
	_binding_confirm_button.text = "ЗАМЕНИТЬ" if is_russian else "REPLACE"
	_binding_cancel_button.text = "ОТМЕНА" if is_russian else "CANCEL"
	_binding_reset_button.text = "СБРОСИТЬ ПО УМОЛЧАНИЮ" if is_russian else "RESET TO DEFAULTS"
	_binding_back_button.text = "НАЗАД" if is_russian else "BACK"
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
	_refresh_binding_rows()


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
