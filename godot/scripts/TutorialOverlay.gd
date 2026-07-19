class_name TutorialOverlay
extends CanvasLayer

signal finished(tutorial_id: String)

const PANEL_SIZE := Vector2(1080, 620)

var _panel: Panel
var _title: Label
var _body: Label
var _footer: Label
var _diagram: TutorialDiagram
var _tutorial_id := ""
var _language := "ru"
var _config := {}
var _active := false
var _input_armed := false
var _tree_was_paused := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func show_card(config: Dictionary, language: String) -> void:
	if config.is_empty():
		return
	_tutorial_id = config.get("id", "")
	_config = config
	_language = language
	_refresh_text()
	_diagram.set_diagram_kind(config.get("diagram", ""))
	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	_active = true
	_input_armed = false
	visible = true
	call_deferred("_arm_input")


func is_active() -> bool:
	return _active


func set_language(language: String) -> void:
	_language = language
	if _active:
		_refresh_text()


func close_card() -> void:
	if not _active:
		return
	var completed_id := _tutorial_id
	_active = false
	_input_armed = false
	visible = false
	get_tree().paused = _tree_was_paused
	finished.emit(completed_id)


func _arm_input() -> void:
	if _active:
		_input_armed = true


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var settings := get_node_or_null("/root/Settings")
	if is_instance_valid(settings) and (
		settings.is_open() or settings.is_menu_button_pointer_event(event)
	):
		return
	var close_requested: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	)
	close_requested = close_requested or (
		event is InputEventKey
		and event.keycode == KEY_ENTER
		and event.pressed
		and not event.echo
	)
	if close_requested:
		get_viewport().set_input_as_handled()
		if _input_armed:
			close_card()


func _localize(value) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var localized: Dictionary = value
		return str(localized.get(_language, localized.get("en", "")))
	return str(value)


func _refresh_text() -> void:
	_title.text = _localize(_config.get("title", ""))
	_body.text = _localize(_config.get("body", ""))
	_footer.text = _localize({
		"en": "LMB / ENTER — CONTINUE",
		"ru": "ЛКМ / ENTER — ПРОДОЛЖИТЬ",
	})


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.012, 0.018, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)

	_panel = Panel.new()
	_panel.size = PANEL_SIZE
	_panel.position = (Vector2(1280, 720) - PANEL_SIZE) * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.028, 0.035, 0.96)
	panel_style.border_color = Color(0.62, 0.68, 0.72, 0.96)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(42, 24)
	_title.size = Vector2(PANEL_SIZE.x - 84, 42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	_panel.add_child(_title)

	_diagram = TutorialDiagram.new()
	_diagram.position = Vector2(170, 78)
	_diagram.size = Vector2(700, 330)
	_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_diagram)

	_body = Label.new()
	_body.position = Vector2(72, 418)
	_body.size = Vector2(PANEL_SIZE.x - 144, 112)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 21)
	_panel.add_child(_body)

	_footer = Label.new()
	_footer.position = Vector2(72, 560)
	_footer.size = Vector2(PANEL_SIZE.x - 144, 28)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 15)
	_footer.add_theme_color_override("font_color", Color(0.67, 0.70, 0.74))
	_panel.add_child(_footer)
