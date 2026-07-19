class_name AudioRuntime
extends Node

@export var sfx_catalog: AudioCatalog
@export_range(4, 128, 1) var positional_pool_size := 32
@export_range(2, 32, 1) var global_pool_size := 8

var _event_index := {}
var _positional_voices: Array[AudioStreamPlayer2D] = []
var _global_voices: Array[AudioStreamPlayer] = []
var _voice_meta := {}
var _active_plays := {}
var _last_played_at := {}
var _next_play_id := 1
var _music_director: MusicDirector


func _ready() -> void:
	_music_director = get_node_or_null("MusicDirector") as MusicDirector
	rebuild_catalog()
	_create_voice_pools()


func rebuild_catalog() -> void:
	_event_index = sfx_catalog.build_index() if sfx_catalog != null else {}
	var music_director := _get_music_director()
	if music_director != null:
		music_director.rebuild_catalog()


func has_event(event_id: StringName) -> bool:
	return _event_index.has(event_id)


func get_event(event_id: StringName) -> SoundEvent:
	return _event_index.get(event_id)


func play_2d(event_id: StringName, world_position: Vector2) -> bool:
	return _play_event(event_id, world_position, true)


func play_global(event_id: StringName) -> bool:
	return _play_event(event_id, Vector2.ZERO, false)


func play_music(cue_id: StringName, fade_override: float = -1.0) -> bool:
	var music_director := _get_music_director()
	return music_director != null and music_director.play_cue(cue_id, fade_override)


func set_music_state(state: StringName) -> bool:
	var music_director := _get_music_director()
	return music_director != null and music_director.set_state(state)


func stop_music(fade_seconds: float = 0.5) -> void:
	var music_director := _get_music_director()
	if music_director != null:
		music_director.stop_music(fade_seconds)


func set_bus_volume_linear(bus_name: StringName, value: float) -> bool:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return false
	var clamped := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped <= 0.001)
	if clamped > 0.001:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped))
	return true


func stop_group(group: StringName) -> void:
	var play_ids: Array[int] = []
	for play_id in _active_plays:
		var data: Dictionary = _active_plays[play_id]
		if data.get("key", &"") == group:
			play_ids.append(play_id)
	for play_id in play_ids:
		_stop_play(play_id)


func stop_all_sfx() -> void:
	var play_ids: Array[int] = []
	for play_id in _active_plays:
		play_ids.append(play_id)
	for play_id in play_ids:
		_stop_play(play_id)


func get_active_voice_count() -> int:
	return _voice_meta.size()


func validate_catalogs() -> PackedStringArray:
	var errors := PackedStringArray()
	if sfx_catalog == null:
		errors.append("SFX catalog is not assigned")
	else:
		errors.append_array(sfx_catalog.validate())
	var music_director := _get_music_director()
	if music_director != null and music_director.catalog != null:
		errors.append_array(music_director.catalog.validate())
	return errors


func _get_music_director() -> MusicDirector:
	if not is_instance_valid(_music_director):
		_music_director = get_node_or_null("MusicDirector") as MusicDirector
	return _music_director


func _create_voice_pools() -> void:
	for index in range(positional_pool_size):
		var voice := AudioStreamPlayer2D.new()
		voice.name = "PositionalVoice%02d" % index
		voice.finished.connect(_on_voice_finished.bind(voice))
		add_child(voice)
		_positional_voices.append(voice)
	for index in range(global_pool_size):
		var voice := AudioStreamPlayer.new()
		voice.name = "GlobalVoice%02d" % index
		voice.finished.connect(_on_voice_finished.bind(voice))
		add_child(voice)
		_global_voices.append(voice)


func _play_event(event_id: StringName, world_position: Vector2, positional: bool) -> bool:
	if _event_index.is_empty() and sfx_catalog != null:
		rebuild_catalog()
	var event: SoundEvent = _event_index.get(event_id)
	if event == null:
		return false

	var now := Time.get_ticks_msec()
	var last_played: int = _last_played_at.get(event_id, -event.cooldown_ms - 1)
	if event.cooldown_ms > 0 and now - last_played < event.cooldown_ms:
		return false

	var selected_layers: Array[SoundLayer] = []
	for layer in event.layers:
		if layer != null and layer.should_play():
			selected_layers.append(layer)
	if selected_layers.is_empty():
		return false

	var concurrency_key := event.get_concurrency_key()
	var active_ids := _get_active_play_ids(concurrency_key)
	if active_ids.size() >= event.max_instances:
		if not event.steal_oldest:
			return false
		_stop_play(active_ids[0])

	var play_id := _next_play_id
	_next_play_id += 1
	_active_plays[play_id] = {
		"event_id": event_id,
		"key": concurrency_key,
		"priority": event.priority,
		"started": now,
		"remaining": selected_layers.size(),
	}
	_last_played_at[event_id] = now

	for layer in selected_layers:
		var delay := layer.choose_delay_seconds()
		if delay <= 0.0:
			_start_layer(play_id, layer, world_position, positional)
		else:
			var timer := get_tree().create_timer(delay)
			timer.timeout.connect(
				_start_layer.bind(play_id, layer, world_position, positional),
				CONNECT_ONE_SHOT,
			)
	return true


func _start_layer(
	play_id: int,
	layer: SoundLayer,
	world_position: Vector2,
	positional: bool,
) -> void:
	if not _active_plays.has(play_id):
		return
	var play_data: Dictionary = _active_plays[play_id]
	var priority: int = play_data.get("priority", 0)
	var voice: Node = _acquire_voice(positional, priority)
	if voice == null:
		_complete_layer(play_id)
		return

	voice.stream = layer.stream
	voice.bus = layer.bus
	voice.volume_db = layer.choose_volume_db()
	voice.pitch_scale = layer.choose_pitch()
	if voice is AudioStreamPlayer2D:
		voice.global_position = world_position
		voice.max_distance = layer.max_distance
		voice.attenuation = layer.attenuation
	_voice_meta[voice] = {
		"play_id": play_id,
		"priority": priority,
		"started": Time.get_ticks_msec(),
	}
	voice.play()


func _acquire_voice(positional: bool, priority: int) -> Node:
	var pool: Array = _positional_voices if positional else _global_voices
	for voice in pool:
		if not _voice_meta.has(voice) and not voice.playing:
			return voice

	var candidate: Node
	var candidate_priority := 1000000
	var candidate_started := 0
	for voice in pool:
		var meta: Dictionary = _voice_meta.get(voice, {})
		var voice_priority: int = meta.get("priority", 0)
		var voice_started: int = meta.get("started", 0)
		if voice_priority > priority:
			continue
		if (
			candidate == null
			or voice_priority < candidate_priority
			or (voice_priority == candidate_priority and voice_started < candidate_started)
		):
			candidate = voice
			candidate_priority = voice_priority
			candidate_started = voice_started
	if candidate != null:
		_release_voice(candidate, true)
	return candidate


func _on_voice_finished(voice: Node) -> void:
	_release_voice(voice, false)


func _release_voice(voice: Node, stop_audio: bool) -> void:
	var meta: Dictionary = _voice_meta.get(voice, {})
	_voice_meta.erase(voice)
	if stop_audio:
		voice.stop()
	voice.stream = null
	var play_id: int = meta.get("play_id", -1)
	if play_id >= 0:
		_complete_layer(play_id)


func _complete_layer(play_id: int) -> void:
	if not _active_plays.has(play_id):
		return
	var data: Dictionary = _active_plays[play_id]
	data["remaining"] = maxi(0, int(data.get("remaining", 1)) - 1)
	if data["remaining"] <= 0:
		_active_plays.erase(play_id)
	else:
		_active_plays[play_id] = data


func _get_active_play_ids(concurrency_key: StringName) -> Array[int]:
	var result: Array[int] = []
	for play_id in _active_plays:
		var data: Dictionary = _active_plays[play_id]
		if data.get("key", &"") == concurrency_key:
			result.append(play_id)
	result.sort_custom(func(a: int, b: int) -> bool:
		return int(_active_plays[a].get("started", 0)) < int(_active_plays[b].get("started", 0))
	)
	return result


func _stop_play(play_id: int) -> void:
	if not _active_plays.has(play_id):
		return
	_active_plays.erase(play_id)
	var voices_to_stop: Array[Node] = []
	for voice in _voice_meta:
		var meta: Dictionary = _voice_meta[voice]
		if int(meta.get("play_id", -1)) == play_id:
			voices_to_stop.append(voice)
	for voice in voices_to_stop:
		_release_voice(voice, true)
