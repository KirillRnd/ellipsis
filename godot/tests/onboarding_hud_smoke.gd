extends SceneTree

const EXPECTED_TUTORIAL_COUNT := 6
const EXPECTED_GAMEPLAY_ACTIONS := [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"dash",
	"crossbar",
	"place_resonator",
	"resonator_volley",
	"cursor_left",
	"cursor_right",
	"cursor_up",
	"cursor_down",
	"toggle_pause_menu",
]


func _init() -> void:
	for action_name in EXPECTED_GAMEPLAY_ACTIONS:
		if not InputMap.has_action(action_name):
			_fail("missing gameplay input action: %s" % action_name)
			return

	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var music_director: MusicDirector = root.get_node("Audio/MusicDirector") as MusicDirector

	var phase_cursor: PhaseCursor = main.get_node_or_null("PhaseCursor") as PhaseCursor
	if not is_instance_valid(phase_cursor):
		_fail("phase cursor is missing from the main scene")
		return
	var cursor_visual := phase_cursor.get_node_or_null("Visual") as TextureRect
	if not is_instance_valid(cursor_visual) or cursor_visual.texture == null:
		_fail("phase cursor visual is missing")
		return
	if not is_equal_approx(cursor_visual.size.x, PhaseCursor.MOUSE_SIZE):
		_fail("phase cursor must start at the mouse scale")
		return

	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = Vector2(420.0, 250.0)
	phase_cursor._input(mouse_motion)
	if not phase_cursor.get_world_position().is_equal_approx(mouse_motion.position):
		_fail("mouse motion must update the shared cursor hotspot")
		return

	var gamepad_start := phase_cursor.get_world_position()
	Input.action_press("cursor_right")
	phase_cursor._process(0.1)
	Input.action_release("cursor_right")
	if phase_cursor.get_world_position().x <= gamepad_start.x:
		_fail("right stick must move the shared cursor")
		return
	if not is_equal_approx(cursor_visual.size.x, PhaseCursor.GAMEPAD_SIZE):
		_fail("gamepad cursor must use the readable gamepad scale")
		return

	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(600.0, 360.0)
	touch.pressed = true
	phase_cursor._input(touch)
	if not phase_cursor.get_world_position().is_equal_approx(touch.position):
		_fail("touch input must place the shared cursor hotspot directly under the tap")
		return
	if not is_equal_approx(cursor_visual.size.x, PhaseCursor.TOUCH_SIZE):
		_fail("touch cursor must use the readable touch scale")
		return

	if main._state != "interlude":
		_fail("room 1 must begin with a narrative interlude")
		return
	if music_director.get_current_cue_id() != &"dialogue":
		_fail("ordinary interludes must use the dialogue music cue")
		return
	if not main._interlude_overlay.is_typing():
		_fail("interlude dialogue must begin with typewriter reveal")
		return
	if not is_equal_approx(InterludeOverlay.TYPEWRITER_SPEED_MULTIPLIER, 1.7):
		_fail("interlude typewriter speed multiplier must be 1.7")
		return
	var audio_runtime: AudioRuntime = root.get_node("Audio") as AudioRuntime
	var visible_before: int = main._interlude_overlay._dialogue.visible_characters
	main._interlude_overlay._process(0.04)
	if main._interlude_overlay._dialogue.visible_characters <= visible_before:
		_fail("typewriter processing must reveal dialogue characters")
		return
	if audio_runtime.get_active_voice_count() <= 0:
		_fail("revealing dialogue characters must play a voice phoneme")
		return
	var first_message_index: int = main._interlude_overlay._message_index
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._interlude_overlay._input(click)
	if (
		main._interlude_overlay._message_index != first_message_index
		or main._interlude_overlay.is_typing()
	):
		_fail("first LMB must reveal the current interlude line")
		return
	main._interlude_overlay._input(click)
	if main._interlude_overlay._message_index != first_message_index + 1:
		_fail("second LMB must advance an interlude")
		return
	while main._interlude_overlay.is_active():
		main._interlude_overlay.advance()
	await process_frame
	if music_director.get_current_cue_id() != &"rooms":
		_fail("ordinary rooms must use the rooms music cue")
		return

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
	if not await _expect_room_entry_tutorial(main, 4, true):
		return
	main._apply_pickup("resonator_capacity")
	if main._tutorial_overlay.is_active():
		_fail("room 5 pickup must not repeat its entry tutorial")
		return
	if not await _expect_room_entry_tutorial(main, 5, true):
		return
	main._apply_pickup("steel_crossbar")
	if main._tutorial_overlay.is_active():
		_fail("room 6 pickup must not repeat its entry tutorial")
		return
	for room_index in [6, 7]:
		if not await _expect_room_entry_tutorial(main, room_index, false):
			return
	if music_director.get_current_cue_id() != &"rahn_battle":
		_fail("Rahn's room must use the Rahn battle music cue")
		return

	main._load_encounter(7)
	await process_frame
	if music_director.get_current_cue_id() != &"rahn_dialogue":
		_fail("Rahn's interlude must use the Rahn dialogue music cue")
		return
	while main._interlude_overlay.is_active():
		main._interlude_overlay.advance()
	await process_frame
	if music_director.get_current_cue_id() != &"rahn_battle":
		_fail("Rahn's battle cue must resume after his interlude")
		return
	if not is_equal_approx(main.RAHN_DEFEAT_MUSIC_FADE_SECONDS, 1.25):
		_fail("Rahn's defeat music fade must last 1.25 seconds")
		return
	main._on_rahn_defeat_started(main._rahn_boss)
	if not music_director.get_current_cue_id().is_empty():
		_fail("Rahn's defeat animation must start the battle music fade")
		return
	main._on_rahn_defeated(main._rahn_boss)
	if main._state != "room_clear":
		_fail("Rahn's completed defeat must unlock the exit")
		return
	main.player.global_position = main._exit_trigger_rect.get_center()
	main._handle_room_exit()
	await process_frame
	if main._state != "victory" or music_director.get_current_cue_id() != &"demo_clear":
		_fail("the final exit must start the demo clear music cue")
		return
	if (
		not is_instance_valid(music_director._active_player)
		or music_director._active_player.get_playback_position() < 184.9
	):
		_fail("the demo clear music must start at 185 seconds")
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

	var diagram := TutorialDiagram.new()
	var first_center := Vector2(235.0, 180.0)
	var second_center := Vector2(465.0, 180.0)
	var intersections := diagram._circle_intersections(first_center, 155.0, second_center, 155.0)
	if intersections.size() != 2:
		_fail("tutorial resonance geometry must have two intersections")
		return
	for point in intersections:
		if (
			not is_equal_approx(point.distance_to(first_center), 155.0)
			or not is_equal_approx(point.distance_to(second_center), 155.0)
		):
			_fail("tutorial resonance nodes must lie on both wave crests")
			return
	diagram.free()

	print("ONBOARDING_HUD_SMOKE_OK")
	root.get_node("Audio").stop_music(0.0)
	root.get_node("Audio").stop_all_sfx()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
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
