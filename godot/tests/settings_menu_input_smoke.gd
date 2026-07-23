extends SceneTree


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null("Settings") as SettingsMenu
	if not is_instance_valid(settings):
		_fail("settings autoload is missing")
		return
	if settings._menu_button.focus_mode != Control.FOCUS_NONE:
		_fail("menu button must not accept keyboard or gamepad focus")
		return
	if settings._close_button.focus_mode != Control.FOCUS_NONE:
		_fail("close button must not accept keyboard or gamepad focus")
		return

	settings.open_settings()
	settings.close_settings()
	if settings._menu_button.has_focus():
		_fail("menu button retained focus after closing settings")
		return

	var gameplay_key := InputEventKey.new()
	gameplay_key.keycode = KEY_SPACE
	gameplay_key.physical_keycode = KEY_SPACE
	gameplay_key.pressed = true
	Input.parse_input_event(gameplay_key)
	await process_frame
	if settings.is_open():
		_fail("a gameplay key reopened the settings menu")
		return

	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.physical_keycode = KEY_ESCAPE
	escape_key.pressed = true
	Input.parse_input_event(escape_key)
	await process_frame
	if not settings.is_open():
		_fail("toggle_pause_menu did not open settings on Escape")
		return

	escape_key.pressed = false
	Input.parse_input_event(escape_key)
	await process_frame
	escape_key.pressed = true
	Input.parse_input_event(escape_key)
	await process_frame
	if settings.is_open():
		_fail("toggle_pause_menu did not close settings on Escape")
		return

	print("SETTINGS MENU INPUT SMOKE OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("SETTINGS MENU INPUT SMOKE FAILED: %s" % message)
	quit(1)
