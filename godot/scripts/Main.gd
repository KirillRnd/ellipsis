extends Node2D

const ENCOUNTER_ID := "mvp_combat_test"
const DEFAULT_BATTLE_LENGTH := 90.0
const DEFAULT_GAME_SPEED := 0.333333
const DEFAULT_KILLS_TO_WIN := 3
const DEFAULT_NEXT_EMITTER_DELAY := 2.0
const HUD_TOP_Y := 8.0
const HUD_SECOND_Y := 34.0
const HUD_BOTTOM_Y := 674.0
const ENCOUNTER_CATALOG := preload("res://scripts/EncounterCatalog.gd")
const BLUE_BEACON_SCRIPT := preload("res://scripts/BlueBeacon.gd")
const RESONATOR_SCRIPT := preload("res://scripts/Resonator.gd")
const WAVE_EMITTER_SCENE := preload("res://scenes/WaveEmitter.tscn")
const DEFAULT_RESONATOR_PLACE_RANGE := 190.0

@onready var wave_manager = $WaveManager
@onready var player = $Player

var _state := "combat"
var _elapsed := 0.0
var _kills := 0
var _next_emitter_index := 1
var _restart_was_down := false
var _resonator_was_down := false
var _scheduled_active_times: Array = []
var _blue_beacon
var _blue_beacon_wave_config := {}
var _battle_length := DEFAULT_BATTLE_LENGTH
var _kills_to_win := DEFAULT_KILLS_TO_WIN
var _next_emitter_delay := DEFAULT_NEXT_EMITTER_DELAY
var _resonator_place_range := DEFAULT_RESONATOR_PLACE_RANGE
var _emitters: Array = []
var _resonator
var _timer_label: Label
var _hp_label: Label
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	var encounter: Dictionary = ENCOUNTER_CATALOG.get_encounter(ENCOUNTER_ID)
	_apply_encounter_settings(encounter)

	wave_manager.player = player
	_create_emitters(encounter.get("emitters", []))
	wave_manager.emitters = _emitters
	player.fired_counter_wave.connect(_on_player_fired_counter_wave)
	player.hit_points_changed.connect(_on_player_hit_points_changed)
	player.died.connect(_on_player_died)
	wave_manager.danger_changed.connect(_on_danger_changed)

	_scheduled_active_times.clear()
	for i in range(_emitters.size()):
		var emitter = _emitters[i]
		emitter.wave_manager = wave_manager
		_scheduled_active_times.append(emitter.active_at)
		emitter.defeated.connect(_on_emitter_defeated)

	_create_blue_beacon(encounter.get("blue_beacon", {}))
	_create_ui()
	_update_ui()


func _apply_encounter_settings(encounter: Dictionary) -> void:
	Engine.time_scale = encounter.get("game_speed", DEFAULT_GAME_SPEED)
	_battle_length = encounter.get("battle_length", DEFAULT_BATTLE_LENGTH)
	_kills_to_win = encounter.get("kills_to_win", DEFAULT_KILLS_TO_WIN)
	_next_emitter_delay = encounter.get("next_emitter_delay", DEFAULT_NEXT_EMITTER_DELAY)
	_resonator_place_range = encounter.get("resonator_place_range", DEFAULT_RESONATOR_PLACE_RANGE)
	player.global_position = encounter.get("player_position", player.global_position)


func _create_emitters(emitter_configs: Array) -> void:
	for emitter_config in emitter_configs:
		var emitter = WAVE_EMITTER_SCENE.instantiate()
		emitter.name = emitter_config.get("name", "WaveEmitter")
		emitter.global_position = emitter_config.get("position", Vector2.ZERO)
		emitter.wave_kind = emitter_config.get("wave_kind", emitter.wave_kind)
		emitter.interval = emitter_config.get("interval", emitter.interval)
		emitter.initial_delay = emitter_config.get("initial_delay", emitter.initial_delay)
		emitter.active_at = emitter_config.get("active_at", emitter.active_at)
		emitter.max_hit_points = emitter_config.get("max_hit_points", emitter.max_hit_points)
		add_child(emitter)
		_emitters.append(emitter)


func _process(delta: float) -> void:
	_handle_restart()
	if _state != "combat":
		_update_emitters(false)
		_update_blue_beacon(false)
		return

	_elapsed += delta
	player.counter_wave_enabled = true
	_update_emitters(true)
	_update_blue_beacon(true)
	_handle_resonator_input()
	_update_ui()


func _handle_restart() -> void:
	var restart_down := Input.is_key_pressed(KEY_R)
	if restart_down and not _restart_was_down:
		get_tree().reload_current_scene()
	_restart_was_down = restart_down


func _update_emitters(running: bool) -> void:
	for emitter in _emitters:
		emitter.combat_time = _elapsed
		emitter.combat_running = running


func _update_blue_beacon(running: bool) -> void:
	if not is_instance_valid(_blue_beacon):
		return
	_blue_beacon.combat_time = _elapsed
	_blue_beacon.combat_running = running


func _create_blue_beacon(config: Dictionary) -> void:
	if config.is_empty():
		return
	_blue_beacon = BLUE_BEACON_SCRIPT.new()
	_blue_beacon.name = config.get("name", "BlueBeacon")
	_blue_beacon.global_position = config.get("position", Vector2.ZERO)
	_blue_beacon_wave_config = config.get("wave", {})
	_blue_beacon.fired_friendly_wave.connect(_on_blue_beacon_fired)
	add_child(_blue_beacon)


func _on_player_fired_counter_wave(origin: Vector2) -> void:
	wave_manager.spawn_wave("player", "violet", origin)
	if is_instance_valid(_resonator):
		wave_manager.spawn_wave("player", "resonator", _resonator.global_position)
		_resonator.trigger()
	_status_label.text = "COUNTER WAVE"


func _on_blue_beacon_fired(origin: Vector2) -> void:
	wave_manager.spawn_wave("player", "blue", origin, _blue_beacon_wave_config)
	_status_label.text = "BLUE SOURCE"


func _handle_resonator_input() -> void:
	var resonator_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if resonator_down and not _resonator_was_down:
		_place_resonator(_get_resonator_target_position())
	_resonator_was_down = resonator_down


func _get_resonator_target_position() -> Vector2:
	var target: Vector2 = get_global_mouse_position()
	var offset: Vector2 = target - player.global_position
	if offset.length() > _resonator_place_range:
		target = player.global_position + offset.normalized() * _resonator_place_range
	return target.clamp(PlayerController.ARENA_RECT.position, PlayerController.ARENA_RECT.end)


func _place_resonator(target: Vector2) -> void:
	if is_instance_valid(_resonator):
		_resonator.queue_free()
	_resonator = RESONATOR_SCRIPT.new()
	_resonator.name = "Resonator"
	_resonator.global_position = target
	_resonator.expired.connect(_on_resonator_expired)
	add_child(_resonator)
	_status_label.text = "RESONATOR SET"


func _on_resonator_expired(resonator) -> void:
	if resonator == _resonator:
		_resonator = null


func _on_player_hit_points_changed(hit_points: int) -> void:
	if is_instance_valid(_hp_label):
		_hp_label.text = "HP %d/30" % max(hit_points, 0)


func _on_player_died() -> void:
	_set_state("defeat")


func _on_emitter_defeated(_emitter) -> void:
	if _state != "combat":
		return
	_kills += 1
	if _kills >= _kills_to_win:
		_set_state("victory")
		return
	_accelerate_next_scheduled_emitter()
	_status_label.text = "TARGET DOWN"
	_update_ui()


func _accelerate_next_scheduled_emitter() -> void:
	while _next_emitter_index < _emitters.size():
		var next_emitter = _emitters[_next_emitter_index]
		if not is_instance_valid(next_emitter) or next_emitter.is_destroyed():
			_next_emitter_index += 1
			continue
		if _elapsed >= next_emitter.active_at:
			_next_emitter_index += 1
			continue
		next_emitter.active_at = minf(next_emitter.active_at, _elapsed + _next_emitter_delay)
		_next_emitter_index += 1
		return


func _on_danger_changed(danger_value: int) -> void:
	if _state != "combat":
		return
	if danger_value < 0:
		_status_label.text = "SAFE LANE"
	elif danger_value > 1:
		_status_label.text = "DANGER NODE"


func _set_state(new_state: String) -> void:
	if _state == new_state:
		return
	_state = new_state
	player.counter_wave_enabled = false
	if _state == "victory":
		_status_label.text = "VICTORY"
		_hint_label.text = "%d emitters defeated. Press R to restart." % _kills_to_win
	elif _state == "defeat":
		_status_label.text = "DEFEAT"
		_hint_label.text = "All HP lost. Press R to restart."


func _create_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	_timer_label = Label.new()
	_timer_label.position = Vector2(24, HUD_TOP_Y)
	_timer_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(_timer_label)

	_hp_label = Label.new()
	_hp_label.position = Vector2(24, HUD_SECOND_Y)
	_hp_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(_hp_label)

	_status_label = Label.new()
	_status_label.position = Vector2(520, HUD_TOP_Y)
	_status_label.add_theme_font_size_override("font_size", 26)
	ui.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(430, HUD_BOTTOM_Y)
	_hint_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(_hint_label)

	_on_player_hit_points_changed(player.hit_points)


func _update_ui() -> void:
	var time_left := maxf(0.0, _battle_length - _elapsed)
	_timer_label.text = "TIME %05.1f  KILLS %d/%d" % [time_left, _kills, _kills_to_win]

	if _state == "combat":
		if not player.counter_wave_enabled:
			_status_label.text = "SURVIVE"
			_hint_label.text = "WASD move | Space dash | LMB wave, hold cascade | RMB resonator | R restart"
		elif player.get_cooldown_ratio() > 0.0:
			_status_label.text = "RECHARGING"
			_hint_label.text = "WASD move | Space dash | LMB wave, hold cascade | RMB resonator | R restart"
		else:
			_status_label.text = "COUNTER READY"
			_hint_label.text = "WASD move | Space dash | LMB wave, hold cascade | RMB resonator | R restart"
