extends SceneTree

const EXPECTED_SFX_EVENT_COUNT := 17
const EXPECTED_MUSIC_CUE_COUNT := 5
const EXPECTED_MUSIC_FILES := [
	"Crimson Steppe.mp3",
	"Gears of the Gilded Age.mp3",
	"The Clockwork Garden.mp3",
	"The Idle Mechanism.mp3",
]


func _init() -> void:
	await process_frame

	var sfx_catalog := load("res://audio/catalogs/main_sfx_catalog.tres") as AudioCatalog
	if sfx_catalog == null:
		_fail("SFX catalog does not load")
		return
	var sfx_errors := sfx_catalog.validate()
	if not sfx_errors.is_empty():
		_fail("SFX catalog validation failed: %s" % ", ".join(sfx_errors))
		return
	if sfx_catalog.events.size() != EXPECTED_SFX_EVENT_COUNT:
		_fail("SFX catalog must contain exactly %d events" % EXPECTED_SFX_EVENT_COUNT)
		return
	for event in sfx_catalog.events:
		if event.layers.is_empty():
			_fail("SFX event %s has no layers" % event.event_id)
			return
		var playable_layer_count := 0
		for layer in event.layers:
			if layer != null and layer.stream != null:
				playable_layer_count += 1
		if playable_layer_count == 0:
			_fail("SFX event %s has no playable layers" % event.event_id)
			return

	var music_catalog := load("res://audio/catalogs/main_music_catalog.tres") as MusicCatalog
	if music_catalog == null:
		_fail("music catalog does not load")
		return
	var music_errors := music_catalog.validate()
	if not music_errors.is_empty():
		_fail("music catalog validation failed: %s" % ", ".join(music_errors))
		return
	if music_catalog.cues.size() != EXPECTED_MUSIC_CUE_COUNT:
		_fail("music catalog must contain exactly %d cues" % EXPECTED_MUSIC_CUE_COUNT)
		return
	for cue in music_catalog.cues:
		if not cue.stream is AudioStreamMP3:
			_fail("music cue %s must use MP3 at runtime" % cue.cue_id)
			return

	var music_directory := DirAccess.open("res://assets/audio/music")
	if music_directory == null:
		_fail("runtime music directory is missing")
		return
	var actual_music_files: Array[String] = []
	for file_name in music_directory.get_files():
		if file_name.ends_with(".wav"):
			_fail("runtime music directory contains WAV: %s" % file_name)
			return
		if file_name.ends_with(".mp3"):
			actual_music_files.append(file_name)
	actual_music_files.sort()
	var expected_music_files: Array[String] = []
	expected_music_files.assign(EXPECTED_MUSIC_FILES)
	expected_music_files.sort()
	if actual_music_files != expected_music_files:
		_fail(
			"runtime MP3 set differs: expected %s, got %s"
			% [expected_music_files, actual_music_files]
		)
		return

	print("AUDIO_ASSETS_SMOKE_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error("AUDIO_ASSETS_SMOKE_FAILED: %s" % message)
	quit(1)
