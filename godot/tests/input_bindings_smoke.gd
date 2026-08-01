extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var settings := root.get_node_or_null("Settings") as SettingsMenu
	_expect(is_instance_valid(settings), "Settings autoload exists")
	if not is_instance_valid(settings):
		_finish()
		return

	var q_event := InputEventKey.new()
	q_event.keycode = KEY_K
	q_event.pressed = true
	settings._begin_rebind(&"dash")
	_expect(settings._try_capture_binding_event(q_event), "keyboard input is captured")
	_expect(_action_has_event(&"dash", q_event), "captured input is applied immediately")

	settings._begin_rebind(&"move_left")
	settings._try_capture_binding_event(q_event)
	_expect(not settings._pending_conflicts.is_empty(), "binding conflict is reported before replacement")
	_expect(not _action_has_event(&"move_left", q_event), "conflicting input waits for confirmation")
	settings._confirm_conflicting_binding()
	_expect(_action_has_event(&"move_left", q_event), "confirmed input replaces target binding")
	_expect(not _action_has_event(&"dash", q_event), "confirmed conflict is removed from previous action")

	settings._reset_bindings()
	_expect(not _action_has_event(&"move_left", q_event), "reset restores the original layout")
	_expect(not settings.get_action_binding_text(&"dash").is_empty(), "binding has display text")

	var config := ConfigFile.new()
	_expect(config.load(SettingsMenu.SETTINGS_PATH) == OK, "bindings are persisted in settings.cfg")
	_expect(config.has_section_key("input", "dash"), "persisted config contains gameplay actions")
	_finish()


func _action_has_event(action: StringName, candidate: InputEvent) -> bool:
	for event in InputMap.action_get_events(action):
		if event.is_match(candidate):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("input_bindings_smoke: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("input_bindings_smoke: %s" % failure)
	quit(1)
