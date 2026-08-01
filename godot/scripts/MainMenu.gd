extends Control

const GAME_SCENE := "res://main.tscn"
const DEVELOPER_ROOM_SCENE := "res://scenes/DeveloperRoom.tscn"
const BACKGROUND := preload("res://assets/ui/main_menu/Ellipsis.png")

const TEXT := {
	"title": {"ru": "ЭЛЛИПС", "en": "ELLIPSE"},
	"new_game": {"ru": "НОВАЯ ИГРА", "en": "NEW GAME"},
	"developer_room": {"ru": "КОМНАТА РАЗРАБОТЧИКА", "en": "DEVELOPER ROOM"},
	"settings": {"ru": "НАСТРОЙКИ", "en": "SETTINGS"},
	"quit": {"ru": "ВЫХОД", "en": "QUIT"},
	"version": {"ru": "ИТЕРАЦИЯ 6.0", "en": "ITERATION 6.0"},
}

var _settings
var _title: Label
var _version: Label
var _new_game: Button
var _developer_room: Button
var _settings_button: Button
var _quit: Button


func _ready() -> void:
	_settings = get_node_or_null("/root/Settings")
	if is_instance_valid(_settings):
		_settings.set_menu_button_visible(false)
		_settings.language_changed.connect(_refresh_text)
	_build_ui()
	_refresh_text()
	_new_game.grab_focus()


func _build_ui() -> void:
	var background := TextureRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.name = "ReadabilityShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.010, 0.016, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270.0
	panel.offset_top = -270.0
	panel.offset_right = 270.0
	panel.offset_bottom = 270.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 38)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "MenuButtons"
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	column.add_child(_title)

	_version = Label.new()
	_version.name = "Version"
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version.add_theme_font_size_override("font_size", 15)
	_version.add_theme_color_override("font_color", Color(0.66, 0.72, 0.80))
	column.add_child(_version)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18.0
	column.add_child(spacer)

	_new_game = _make_button("NewGameButton", _start_new_game)
	_developer_room = _make_button("DeveloperRoomButton", _open_developer_room)
	_settings_button = _make_button("SettingsButton", _open_settings)
	_quit = _make_button("QuitButton", _quit_game)
	column.add_child(_new_game)
	column.add_child(_developer_room)
	column.add_child(_settings_button)
	column.add_child(_quit)


func _make_button(node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(440.0, 62.0)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.025, 0.035, 0.052, 0.91), Color(0.46, 0.55, 0.68)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.085, 0.12, 0.17, 0.97), Color(0.68, 0.79, 0.94)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.075, 0.11, 0.16, 0.98), Color(0.82, 0.90, 1.0), 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.14, 0.18, 0.24, 1.0), Color(0.90, 0.94, 1.0), 2))
	button.pressed.connect(callback)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.017, 0.027, 0.91)
	style.border_color = Color(0.42, 0.49, 0.60, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 22
	return style


func _button_style(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	return style


func _refresh_text(_language: String = "") -> void:
	if not is_instance_valid(_title):
		return
	var language := "ru"
	if is_instance_valid(_settings):
		language = _settings.current_language
	_title.text = TEXT["title"][language]
	_version.text = TEXT["version"][language]
	_new_game.text = TEXT["new_game"][language]
	_developer_room.text = TEXT["developer_room"][language]
	_settings_button.text = TEXT["settings"][language]
	_quit.text = TEXT["quit"][language]


func _start_new_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _open_developer_room() -> void:
	get_tree().change_scene_to_file(DEVELOPER_ROOM_SCENE)


func _open_settings() -> void:
	if is_instance_valid(_settings):
		_settings.open_settings()


func _quit_game() -> void:
	get_tree().quit()
