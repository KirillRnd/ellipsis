extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

var _settings


func _ready() -> void:
	_settings = get_node_or_null("/root/Settings")
	if is_instance_valid(_settings):
		_settings.set_menu_button_visible(false)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.022, 0.030)
	add_child(background)

	var title := Label.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-300.0, 90.0)
	title.size = Vector2(600.0, 60.0)
	title.text = "КОМНАТА РАЗРАБОТЧИКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)

	var note := Label.new()
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	note.position = Vector2(-350.0, -30.0)
	note.size = Vector2(700.0, 60.0)
	note.text = "Полигон Резонаторов готовится"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 22)
	add_child(note)

	var back := Button.new()
	back.name = "BackButton"
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-160.0, -110.0)
	back.size = Vector2(320.0, 56.0)
	back.text = "В ГЛАВНОЕ МЕНЮ"
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_return_to_menu)
	add_child(back)
	back.grab_focus()


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
