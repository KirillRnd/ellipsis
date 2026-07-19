class_name InterludeOverlay
extends CanvasLayer

signal finished

const DEFAULT_CHARACTERS_PER_SECOND := 34.0
const DEFAULT_CHARACTERS_PER_SOUND := 2
const TYPEWRITER_SPEED_MULTIPLIER := 1.7
const SPEAKER_VOICE_IDS := {
	"COLORLESS": &"colorless",
	"CRON": &"cron",
	"RAHN": &"rahn",
	"TIU": &"tiu",
	"IRVEL": &"irvel",
	"GOLDEN KNIGHT": &"golden",
	"ORUM": &"orum",
	"VARN": &"varn",
	"UNDEAD": &"hollow_armor",
}
const VOICE_PROFILES := {
	&"colorless": {"event": &"dialogue.voice.colorless", "speed": 35.0, "step": 2},
	&"cron": {"event": &"dialogue.voice.cron", "speed": 31.0, "step": 2},
	&"rahn": {"event": &"dialogue.voice.rahn", "speed": 25.0, "step": 2},
	&"violet": {"event": &"dialogue.voice.violet", "speed": 38.0, "step": 2},
	&"irvel": {"event": &"dialogue.voice.irvel", "speed": 32.0, "step": 3},
	&"tiu": {"event": &"dialogue.voice.tiu", "speed": 39.0, "step": 2},
	&"golden": {"event": &"dialogue.voice.golden", "speed": 24.0, "step": 3},
	&"orum": {"event": &"dialogue.voice.orum", "speed": 27.0, "step": 2},
	&"varn": {"event": &"dialogue.voice.varn", "speed": 30.0, "step": 2},
	&"hollow_armor": {"event": &"dialogue.voice.hollow_armor", "speed": 21.0, "step": 3},
}
const PUNCTUATION_PAUSES := {
	",": 0.055,
	";": 0.075,
	":": 0.075,
	".": 0.13,
	"!": 0.14,
	"?": 0.14,
	"…": 0.18,
	"—": 0.08,
	"–": 0.08,
}

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
var _full_dialogue_text := ""
var _revealed_characters := 0
var _reveal_accumulator := 0.0
var _punctuation_pause_remaining := 0.0
var _typing_active := false
var _characters_per_second := DEFAULT_CHARACTERS_PER_SECOND
var _characters_per_sound := DEFAULT_CHARACTERS_PER_SOUND
var _characters_until_sound := 0
var _voice_event: StringName = &"dialogue.voice.colorless"
var _audio: AudioRuntime


func _ready() -> void:
	layer = 50
	_audio = get_node_or_null("/root/Audio") as AudioRuntime
	_build_ui()
	visible = false


func _process(delta: float) -> void:
	if not _active or not _typing_active:
		return
	if _punctuation_pause_remaining > 0.0:
		_punctuation_pause_remaining = maxf(0.0, _punctuation_pause_remaining - delta)
		return
	_reveal_accumulator += delta
	var character_interval := 1.0 / maxf(1.0, _characters_per_second)
	while _typing_active and _reveal_accumulator >= character_interval:
		_reveal_accumulator -= character_interval
		_reveal_next_character()
		if _punctuation_pause_remaining > 0.0:
			break


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
	if _typing_active:
		_finish_typing()
		return
	_message_index += 1
	if _message_index >= _messages.size():
		_finish_typing()
		_active = false
		visible = false
		finished.emit()
		return
	_show_message()


func is_active() -> bool:
	return _active


func is_typing() -> bool:
	return _typing_active


func set_language(language: String) -> void:
	_language = language
	if _active:
		_show_message()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var settings := get_node_or_null("/root/Settings")
	if is_instance_valid(settings) and (
		settings.is_open() or settings.is_menu_button_pointer_event(event)
	):
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
	_full_dialogue_text = _localize(message.get("text", ""))
	_dialogue.text = _full_dialogue_text
	_dialogue.visible_characters = 0
	_revealed_characters = 0
	_reveal_accumulator = 0.0
	_punctuation_pause_remaining = 0.0
	_typing_active = not _full_dialogue_text.is_empty()
	_configure_voice(message)
	_counter.text = "%d / %d    [LMB / ENTER]" % [_message_index + 1, _messages.size()]


func _configure_voice(message: Dictionary) -> void:
	var voice_id := StringName(str(message.get("voice", "")))
	if voice_id.is_empty():
		voice_id = _resolve_speaker_voice(message.get("speaker", ""))
	var profile: Dictionary = VOICE_PROFILES.get(voice_id, VOICE_PROFILES[&"colorless"])
	_voice_event = profile.get("event", &"dialogue.voice.colorless")
	_characters_per_second = maxf(
		1.0,
		float(message.get("characters_per_second", profile.get("speed", DEFAULT_CHARACTERS_PER_SECOND)))
		* TYPEWRITER_SPEED_MULTIPLIER
	)
	_characters_per_sound = maxi(
		1,
		int(message.get("characters_per_sound", profile.get("step", DEFAULT_CHARACTERS_PER_SOUND)))
	)
	_characters_until_sound = 0


func _resolve_speaker_voice(speaker_value) -> StringName:
	var canonical_name := ""
	if typeof(speaker_value) == TYPE_DICTIONARY:
		var localized_names: Dictionary = speaker_value
		canonical_name = str(localized_names.get("en", ""))
	else:
		canonical_name = str(speaker_value)
	return SPEAKER_VOICE_IDS.get(canonical_name.strip_edges().to_upper(), &"colorless")


func _reveal_next_character() -> void:
	if _revealed_characters >= _full_dialogue_text.length():
		_finish_typing()
		return
	var character := _full_dialogue_text.substr(_revealed_characters, 1)
	_revealed_characters += 1
	_dialogue.visible_characters = _revealed_characters
	if PUNCTUATION_PAUSES.has(character):
		_punctuation_pause_remaining = (
			float(PUNCTUATION_PAUSES[character]) / TYPEWRITER_SPEED_MULTIPLIER
		)
		_characters_until_sound = 0
	elif not character.strip_edges().is_empty():
		if _characters_until_sound <= 0:
			_play_voice_phoneme()
			_characters_until_sound = _characters_per_sound - 1
		else:
			_characters_until_sound -= 1
	if _revealed_characters >= _full_dialogue_text.length():
		_finish_typing()


func _play_voice_phoneme() -> void:
	if not is_instance_valid(_audio):
		_audio = get_node_or_null("/root/Audio") as AudioRuntime
	if _audio != null:
		_audio.play_global(_voice_event)


func _finish_typing() -> void:
	_typing_active = false
	_punctuation_pause_remaining = 0.0
	_reveal_accumulator = 0.0
	_revealed_characters = _full_dialogue_text.length()
	if is_instance_valid(_dialogue):
		_dialogue.visible_characters = -1


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
