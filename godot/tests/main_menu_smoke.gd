extends SceneTree

const MAIN_MENU := preload("res://scenes/MainMenu.tscn")
const DEVELOPER_ROOM := preload("res://scenes/DeveloperRoom.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu = MAIN_MENU.instantiate()
	root.add_child(menu)
	await process_frame

	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/MainMenu.tscn", "MainMenu is the project entry scene")
	_expect(ResourceLoader.exists("res://assets/ui/main_menu/Ellipsis.png"), "Ellipsis background is available")
	_expect(DEVELOPER_ROOM.can_instantiate(), "DeveloperRoom scene can instantiate")

	for button_name in ["NewGameButton", "DeveloperRoomButton", "SettingsButton", "QuitButton"]:
		var button = menu.find_child(button_name, true, false)
		_expect(button is Button, "%s exists" % button_name)
		if button is Button:
			_expect(not button.text.is_empty(), "%s has localized text" % button_name)

	menu.queue_free()
	await process_frame

	if _failures.is_empty():
		print("main_menu_smoke: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("main_menu_smoke: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
