extends Node2D

const BATTLE_LENGTH := 90.0
const GAME_SPEED := 0.333333
const KILLS_TO_WIN := 3
const NEXT_EMITTER_DELAY := 2.0
const HUD_TOP_Y := 8.0
const HUD_SECOND_Y := 34.0
const HUD_BOTTOM_Y := 674.0
const BLUE_BEACON_SCRIPT := preload("res://scripts/BlueBeacon.gd")
const RESONATOR_SCRIPT := preload("res://scripts/Resonator.gd")
const BLUE_BEACON_POSITION := Vector2(305, 515)
const RESONATOR_PLACE_RANGE := 190.0

@onready var wave_manager = $WaveManager
@onready var player = $Player
@onready var emitters: Array = [
	$RedEmitterA,
	$RedEmitterB,
	$GoldEmitter,
]

var _state := "combat"
var _elapsed := 0.0
var _kills := 0
var _next_emitter_index := 1
var _restart_was_down := false
var _resonator_was_down := false
var _scheduled_active_times: Array = []
var _blue_beacon
var _resonator
var _timer_label: Label
var _hp_label: Label
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	Engine.time_scale = GAME_SPEED
	wave_manager.player = player
	wave_manager.emitters = emitters
	player.fired_counter_wave.connect(_on_player_fired_counter_wave)
	player.hit_points_changed.connect(_on_player_hit_points_changed)
	player.died.connect(_on_player_died)
	wave_manager.danger_changed.connect(_on_danger_changed)

	_scheduled_active_times.clear()
	for i in range(emitters.size()):
		var emitter = emitters[i]
		emitter.wave_manager = wave_manager
		_scheduled_active_times.append(emitter.active_at)
		emitter.defeated.connect(_on_emitter_defeated)

	_create_blue_beacon()
	_create_ui()
	_update_ui()


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
	for emitter in emitters:
		emitter.combat_time = _elapsed
		emitter.combat_running = running


func _update_blue_beacon(running: bool) -> void:
	if not is_instance_valid(_blue_beacon):
		return
	_blue_beacon.combat_time = _elapsed
	_blue_beacon.combat_running = running


func _create_blue_beacon() -> void:
	_blue_beacon = BLUE_BEACON_SCRIPT.new()
	_blue_beacon.name = "BlueBeacon"
	_blue_beacon.global_position = BLUE_BEACON_POSITION
	_blue_beacon.fired_friendly_wave.connect(_on_blue_beacon_fired)
	add_child(_blue_beacon)


func _on_player_fired_counter_wave(origin: Vector2) -> void:
	wave_manager.spawn_wave("player", "violet", origin)
	if is_instance_valid(_resonator):
		wave_manager.spawn_wave("player", "resonator", _resonator.global_position)
		_resonator.trigger()
	_status_label.text = "COUNTER WAVE"


func _on_blue_beacon_fired(origin: Vector2) -> void:
	wave_manager.spawn_wave("player", "blue", origin, {
		"speed": 190.0,
		"lifetime": 2.6,
		"max_radius": Wave.RED_MAX_RADIUS,
		"can_damage_emitters": false,
		"can_create_boost": false,
	})
	_status_label.text = "BLUE SOURCE"


func _handle_resonator_input() -> void:
	var resonator_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if resonator_down and not _resonator_was_down:
		_place_resonator(_get_resonator_target_position())
	_resonator_was_down = resonator_down


func _get_resonator_target_position() -> Vector2:
	var target: Vector2 = get_global_mouse_position()
	var offset: Vector2 = target - player.global_position
	if offset.length() > RESONATOR_PLACE_RANGE:
		target = player.global_position + offset.normalized() * RESONATOR_PLACE_RANGE
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
	if _kills >= KILLS_TO_WIN:
		_set_state("victory")
		return
	_accelerate_next_scheduled_emitter()
	_status_label.text = "TARGET DOWN"
	_update_ui()


func _accelerate_next_scheduled_emitter() -> void:
	while _next_emitter_index < emitters.size():
		var next_emitter = emitters[_next_emitter_index]
		if not is_instance_valid(next_emitter) or next_emitter.is_destroyed():
			_next_emitter_index += 1
			continue
		if _elapsed >= next_emitter.active_at:
			_next_emitter_index += 1
			continue
		next_emitter.active_at = minf(next_emitter.active_at, _elapsed + NEXT_EMITTER_DELAY)
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
		_hint_label.text = "3 emitters defeated. Press R to restart."
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
	var time_left := maxf(0.0, BATTLE_LENGTH - _elapsed)
	_timer_label.text = "TIME %05.1f  KILLS %d/%d" % [time_left, _kills, KILLS_TO_WIN]

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

