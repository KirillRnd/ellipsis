extends SceneTree

const EXPECTED_TUTORIAL_COUNT := 6


func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	if main._state != "interlude":
		_fail("room 1 must begin with a narrative interlude")
		return
	var first_message_index: int = main._interlude_overlay._message_index
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._interlude_overlay._input(click)
	if main._interlude_overlay._message_index != first_message_index + 1:
		_fail("LMB must advance an interlude")
		return
	while main._interlude_overlay.is_active():
		main._interlude_overlay.advance()
	await process_frame

	if not main._tutorial_overlay.is_active() or not paused:
		_fail("room 1 tutorial must pause gameplay")
		return
	await process_frame
	main._tutorial_overlay._input(click)
	if main._tutorial_overlay.is_active() or paused:
		_fail("LMB must close a tutorial and restore gameplay")
		return

	if not await _expect_room_entry_tutorial(main, 1, true):
		return
	if not await _expect_room_entry_tutorial(main, 2, false):
		return
	if not _expect_pickup_tutorial(main, "resonator"):
		return
	if not await _expect_room_entry_tutorial(main, 3, true):
		return
	if not await _expect_room_entry_tutorial(main, 4, false):
		return
	if not _expect_pickup_tutorial(main, "resonator_capacity"):
		return
	if not await _expect_room_entry_tutorial(main, 5, false):
		return
	if not _expect_pickup_tutorial(main, "steel_crossbar"):
		return
	for room_index in [6, 7]:
		if not await _expect_room_entry_tutorial(main, room_index, false):
			return

	if main._shown_tutorials.size() != EXPECTED_TUTORIAL_COUNT:
		_fail("tutorials must be one-shot and total exactly six")
		return

	main._load_encounter(5, true)
	await process_frame
	main._place_resonator(Vector2(520.0, 430.0))
	main._place_resonator(Vector2(750.0, 430.0))
	main._resonator_place_cooldown = 0.55 * 0.5
	main._resonator_volley_cooldown = (2.35 * 0.25) * 0.5
	main._update_ability_hud()
	var hud: AbilityHud = main._ability_hud
	if not is_instance_valid(hud):
		_fail("ability HUD is missing")
		return
	if hud._volley_slot._counter != "2/2":
		_fail("ability HUD must expose the two-resonator state")
		return
	if not is_equal_approx(hud._place_slot._readiness, 0.5):
		_fail("placement indicator must use the live cooldown")
		return
	if not is_equal_approx(hud._volley_slot._readiness, 0.5):
		_fail("volley indicator must use the live cooldown")
		return

	var slot: AbilitySlot = hud._place_slot
	var fill_rect: Rect2 = slot.FILL_RECT
	var center := fill_rect.get_center()
	var expected_endpoints := [
		Vector2(fill_rect.end.x, center.y),
		Vector2(center.x, fill_rect.end.y),
		Vector2(fill_rect.position.x, center.y),
		Vector2(center.x, fill_rect.position.y),
	]
	for index in range(expected_endpoints.size()):
		var progress := float(index + 1) * 0.25
		var polygon := slot._clockwise_fill_polygon(progress)
		if polygon.size() < 3 or not polygon[-1].is_equal_approx(expected_endpoints[index]):
			_fail("ability readiness must fill the square clockwise")
			return

	print("ONBOARDING_HUD_SMOKE_OK")
	main.queue_free()
	await process_frame
	quit()


func _expect_room_entry_tutorial(main, room_index: int, expected: bool) -> bool:
	main._load_encounter(room_index, true)
	await process_frame
	if main._tutorial_overlay.is_active() != expected:
		_fail("unexpected tutorial state on room %d" % (room_index + 1))
		return false
	if expected:
		main._tutorial_overlay.close_card()
	return true


func _expect_pickup_tutorial(main, kind: String) -> bool:
	main._apply_pickup(kind)
	if not main._tutorial_overlay.is_active():
		_fail("pickup tutorial missing for %s" % kind)
		return false
	main._tutorial_overlay.close_card()
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
