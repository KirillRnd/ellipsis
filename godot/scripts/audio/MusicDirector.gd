class_name MusicDirector
extends Node

const SILENCE_DB := -80.0

@export var catalog: MusicCatalog

var _cue_index := {}
var _track_a: AudioStreamPlayer
var _track_b: AudioStreamPlayer
var _tracks_connected := false
var _active_player: AudioStreamPlayer
var _current_cue_id: StringName
var _fade_tween: Tween


func _ready() -> void:
	_ensure_tracks()
	rebuild_catalog()


func rebuild_catalog() -> void:
	_cue_index = catalog.build_index() if catalog != null else {}


func has_cue(cue_id: StringName) -> bool:
	return _cue_index.has(cue_id)


func play_cue(cue_id: StringName, fade_override: float = -1.0) -> bool:
	if _cue_index.is_empty() and catalog != null:
		rebuild_catalog()
	var cue: MusicCue = _cue_index.get(cue_id)
	if cue == null or cue.stream == null or not _ensure_tracks():
		return false
	if (
		_current_cue_id == cue_id
		and is_instance_valid(_active_player)
		and _active_player.playing
		and not cue.restart_if_playing
	):
		return true

	var previous_player := _get_transition_source()
	var next_player := _track_b if previous_player == _track_a else _track_a
	var fade_seconds := cue.fade_seconds if fade_override < 0.0 else fade_override

	_stop_player(next_player)
	next_player.stream = cue.stream
	next_player.bus = cue.bus
	next_player.volume_db = SILENCE_DB if fade_seconds > 0.0 else cue.volume_db
	next_player.play(_get_start_position(cue))

	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
		_fade_tween = null
	_active_player = next_player
	_current_cue_id = cue_id

	if fade_seconds <= 0.0:
		if is_instance_valid(previous_player):
			_stop_player(previous_player)
		next_player.volume_db = cue.volume_db
		return true

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(next_player, "volume_db", cue.volume_db, fade_seconds)
	if is_instance_valid(previous_player) and previous_player.playing:
		_fade_tween.tween_property(previous_player, "volume_db", SILENCE_DB, fade_seconds)
		_fade_tween.chain().tween_callback(_stop_player.bind(previous_player))
	return true


func _get_transition_source() -> AudioStreamPlayer:
	if is_instance_valid(_active_player) and _active_player.playing:
		return _active_player
	var track_a_playing := is_instance_valid(_track_a) and _track_a.playing
	var track_b_playing := is_instance_valid(_track_b) and _track_b.playing
	if track_a_playing and track_b_playing:
		return _track_a if _track_a.volume_db >= _track_b.volume_db else _track_b
	if track_a_playing:
		return _track_a
	if track_b_playing:
		return _track_b
	return null


func set_state(state: StringName) -> bool:
	if not is_instance_valid(_active_player) or _active_player.stream == null:
		return false
	if not _active_player.stream is AudioStreamInteractive:
		return false
	if not _active_player.playing:
		_active_player.play()
	var playback := _active_player.get_stream_playback() as AudioStreamPlaybackInteractive
	if playback == null:
		return false
	playback.switch_to_clip_by_name(state)
	return true


func stop_music(fade_seconds: float = 0.5) -> void:
	if not _ensure_tracks():
		return
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
		_fade_tween = null
	if fade_seconds <= 0.0:
		_stop_all_tracks()
		_active_player = null
		_current_cue_id = &""
		return
	_fade_tween = create_tween().set_parallel(true)
	for player in [_track_a, _track_b]:
		if player.playing:
			_fade_tween.tween_property(player, "volume_db", SILENCE_DB, fade_seconds)
	_fade_tween.chain().tween_callback(_stop_all_tracks)
	_active_player = null
	_current_cue_id = &""


func get_current_cue_id() -> StringName:
	return _current_cue_id


func _ensure_tracks() -> bool:
	if not is_instance_valid(_track_a):
		_track_a = get_node_or_null("TrackA") as AudioStreamPlayer
	if not is_instance_valid(_track_b):
		_track_b = get_node_or_null("TrackB") as AudioStreamPlayer
	if _track_a == null or _track_b == null:
		return false
	if not _tracks_connected:
		_track_a.finished.connect(_on_track_finished.bind(_track_a))
		_track_b.finished.connect(_on_track_finished.bind(_track_b))
		_tracks_connected = true
	return true


func _get_start_position(cue: MusicCue) -> float:
	var stream_length := cue.stream.get_length()
	if stream_length <= 0.0:
		return maxf(0.0, cue.start_position_seconds)
	return clampf(cue.start_position_seconds, 0.0, maxf(0.0, stream_length - 0.01))


func _on_track_finished(player: AudioStreamPlayer) -> void:
	if player != _active_player:
		return
	var cue: MusicCue = _cue_index.get(_current_cue_id)
	if cue == null or not cue.loop_enabled or cue.stream == null:
		return
	player.play(_get_start_position(cue))


func _stop_player(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = null


func _stop_all_tracks() -> void:
	_stop_player(_track_a)
	_stop_player(_track_b)
