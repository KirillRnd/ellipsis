extends SceneTree

const REQUIRED_EVENTS := [
	&"resonator.place.player",
	&"resonator.place.enemy",
	&"wave.launch.purple",
	&"wave.launch.blue",
	&"wave.launch.red",
	&"crossbar.install.quick",
	&"crossbar.install.charged",
	&"dialogue.voice.colorless",
	&"dialogue.voice.cron",
	&"dialogue.voice.rahn",
	&"dialogue.voice.violet",
	&"dialogue.voice.irvel",
	&"dialogue.voice.tiu",
	&"dialogue.voice.golden",
	&"dialogue.voice.orum",
	&"dialogue.voice.varn",
	&"dialogue.voice.hollow_armor",
]

const REQUIRED_BUSES := [
	&"Master",
	&"Music",
	&"Ambience",
	&"SFX",
	&"SFX_Player",
	&"SFX_Enemy",
	&"SFX_Waves",
	&"UI",
	&"Dialogue",
]

const REQUIRED_MUSIC_CUES := {
	&"dialogue": 27.0,
	&"rooms": 0.0,
	&"rahn_dialogue": 7.4,
	&"rahn_battle": 56.0,
	&"demo_clear": 176.0,
}

const REQUIRED_MUSIC_FILES := [
	"res://assets/audio/music/Crimson Steppe.mp3",
	"res://assets/audio/music/Gears of the Gilded Age.mp3",
	"res://assets/audio/music/Gilded Rust.mp3",
	"res://assets/audio/music/Idling the War Machine.mp3",
	"res://assets/audio/music/The Clockwork Garden.mp3",
	"res://assets/audio/music/The Idle Mechanism.mp3",
	"res://assets/audio/music/Watchful Silence.mp3",
]

const MUSIC_VOLUME_DB := -5.036
const MUSIC_FADE_SECONDS := 0.4
const MUSIC_BUS_BASE_LINEAR := 0.9
const DIALOGUE_BUS_LINEAR := 0.8


func _init() -> void:
	await process_frame
	var audio = root.get_node_or_null("Audio")
	if audio == null:
		_fail("Audio autoload is missing")
		return

	var catalog_errors: PackedStringArray = audio.validate_catalogs()
	if not catalog_errors.is_empty():
		_fail("audio catalog validation failed: %s" % ", ".join(catalog_errors))
		return
	for music_path in REQUIRED_MUSIC_FILES:
		var music_stream := ResourceLoader.load(music_path)
		if not (music_stream is AudioStreamMP3):
			_fail("music file is not a loadable MP3: %s" % music_path)
			return
	var music_director: MusicDirector = audio.get_node("MusicDirector") as MusicDirector
	var music_cues := music_director.catalog.build_index()
	for cue_id in REQUIRED_MUSIC_CUES:
		if not music_cues.has(cue_id):
			_fail("missing music cue: %s" % cue_id)
			return
		var cue: MusicCue = music_cues[cue_id]
		if cue.stream == null:
			_fail("music cue has no stream: %s" % cue_id)
			return
		if not is_equal_approx(cue.start_position_seconds, REQUIRED_MUSIC_CUES[cue_id]):
			_fail("wrong music start position: %s" % cue_id)
			return
		if not is_equal_approx(cue.volume_db, MUSIC_VOLUME_DB):
			_fail("wrong music volume: %s" % cue_id)
			return
		if not is_equal_approx(cue.fade_seconds, MUSIC_FADE_SECONDS):
			_fail("wrong music fade duration: %s" % cue_id)
			return
		if not cue.loop_enabled:
			_fail("music cue must loop: %s" % cue_id)
			return

	for event_id in REQUIRED_EVENTS:
		if not audio.has_event(event_id):
			_fail("missing audio event: %s" % event_id)
			return
		var event: SoundEvent = audio.get_event(event_id)
		if event.layers.is_empty():
			_fail("audio event has no configurable layers: %s" % event_id)
			return

	for bus_name in REQUIRED_BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("missing audio bus: %s" % bus_name)
			return
	var settings = root.get_node_or_null("Settings")
	if settings == null or not is_equal_approx(
		db_to_linear(settings._music_base_db), MUSIC_BUS_BASE_LINEAR
	):
		_fail("Music bus base volume must be 90 percent")
		return
	var dialogue_bus_index := AudioServer.get_bus_index(&"Dialogue")
	if not is_equal_approx(
		db_to_linear(AudioServer.get_bus_volume_db(dialogue_bus_index)), DIALOGUE_BUS_LINEAR
	):
		_fail("Dialogue bus volume must be 80 percent")
		return
	if not audio.set_bus_volume_linear(&"SFX", 0.75):
		_fail("SFX bus volume cannot be changed")
		return
	audio.set_bus_volume_linear(&"SFX", 1.0)

	audio.stop_all_sfx()
	print("AUDIO_RUNTIME_SMOKE_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
