class_name InterludeOverlay
extends CanvasLayer

signal finished

var _background: TextureRect
var _left: TextureRect
var _right: TextureRect
var _speaker: Label
var _dialogue: Label
var _counter: Label
var _messages: Array = []
var _message_index := 0
var _language := "ru"
var _active := false


func _ready() -> void:
	layer = 50
	_build_ui()
	visible = false


func show_interlude(config: Dictionary, language: String) -> void:
	_language = language
	_messages = config.get("messages", [])
	_message_index = 0
	_background.texture = load(config.get("background", ""))
	_set_portrait(_left, config.get("left", ""))
	_set_portrait(_right, config.get("right", ""))
	_right.position = Vector2(710, 12) if config.get("right_is_item", false) else Vector2(680, 8)
	_right.size = Vector2(500, 560) if config.get("right_is_item", false) else Vector2(580, 610)
	_active = not _messages.is_empty()
	visible = _active
	if _active:
		_show_message()
	else:
		finished.emit()


func advance() -> void:
	if not _active:
		return
	_message_index += 1
	if _message_index >= _messages.size():
		_active = false
		visible = false
		finished.emit()
		return
	_show_message()


func is_active() -> bool:
	return _active


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var advance_requested: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	)
	advance_requested = advance_requested or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_ENTER, KEY_SPACE]
	)
	if advance_requested:
		get_viewport().set_input_as_handled()
		advance()


func _show_message() -> void:
	var message: Dictionary = _messages[_message_index]
	_speaker.text = _localize(message.get("speaker", ""))
	_dialogue.text = _localize(message.get("text", ""))
	_counter.text = "%d / %d    [LMB / ENTER]" % [_message_index + 1, _messages.size()]


func _localize(value) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var localized: Dictionary = value
		return str(localized.get(_language, localized.get("en", "")))
	return str(value)


func _set_portrait(target: TextureRect, path: String) -> void:
	target.texture = load(path) if not path.is_empty() else null
	target.visible = target.texture != null


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.025, 0.035, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	_left = _make_portrait(Vector2(20, 8), Vector2(580, 610))
	root.add_child(_left)
	_right = _make_portrait(Vector2(680, 8), Vector2(580, 610))
	root.add_child(_right)

	var panel := Panel.new()
	panel.position = Vector2(42, 505)
	panel.size = Vector2(1196, 185)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.028, 0.035, 0.94)
	panel_style.border_color = Color(0.62, 0.65, 0.68, 0.96)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	_speaker = Label.new()
	_speaker.position = Vector2(26, 16)
	_speaker.size = Vector2(760, 34)
	_speaker.add_theme_font_size_override("font_size", 23)
	_speaker.add_theme_color_override("font_color", Color(0.93, 0.22, 0.25))
	panel.add_child(_speaker)

	_dialogue = Label.new()
	_dialogue.position = Vector2(26, 52)
	_dialogue.size = Vector2(1144, 90)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.add_theme_font_size_override("font_size", 21)
	panel.add_child(_dialogue)

	_counter = Label.new()
	_counter.position = Vector2(820, 145)
	_counter.size = Vector2(350, 26)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_font_size_override("font_size", 14)
	_counter.add_theme_color_override("font_color", Color(0.68, 0.70, 0.74))
	panel.add_child(_counter)


func _make_portrait(position: Vector2, size: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.position = position
	portrait.size = size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait
