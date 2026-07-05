extends Node2D

const BATTLE_LENGTH := 90.0
const GAME_SPEED := 0.5

@onready var wave_manager = $WaveManager
@onready var player = $Player
@onready var emitters: Array = [
	$RedEmitterA,
	$RedEmitterB,
	$GoldEmitter,
]

var _state := "combat"
var _elapsed := 0.0
var _restart_was_down := false
var _timer_label: Label
var _hp_label: Label
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	Engine.time_scale = GAME_SPEED
	wave_manager.player = player
	player.fired_counter_wave.connect(_on_player_fired_counter_wave)
	player.hit_points_changed.connect(_on_player_hit_points_changed)
	player.died.connect(_on_player_died)
	wave_manager.danger_changed.connect(_on_danger_changed)

	for emitter in emitters:
		emitter.wave_manager = wave_manager

	_create_ui()
	_update_ui()


func _process(delta: float) -> void:
	_handle_restart()
	if _state != "combat":
		_update_emitters(false)
		return

	_elapsed += delta
	player.counter_wave_enabled = true
	_update_emitters(true)

	if _elapsed >= BATTLE_LENGTH:
		_set_state("victory")

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


func _on_player_fired_counter_wave(origin: Vector2) -> void:
	wave_manager.spawn_wave("player", "violet", origin)
	_status_label.text = "COUNTER WAVE"


func _on_player_hit_points_changed(hit_points: int) -> void:
	if is_instance_valid(_hp_label):
		_hp_label.text = "HP %d/100" % max(hit_points, 0)


func _on_player_died() -> void:
	_set_state("defeat")


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
		_hint_label.text = "90 seconds survived. Press R to restart."
	elif _state == "defeat":
		_status_label.text = "DEFEAT"
		_hint_label.text = "All HP lost. Press R to restart."


func _create_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	_timer_label = Label.new()
	_timer_label.position = Vector2(24, 18)
	_timer_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(_timer_label)

	_hp_label = Label.new()
	_hp_label.position = Vector2(24, 48)
	_hp_label.add_theme_font_size_override("font_size", 20)
	ui.add_child(_hp_label)

	_status_label = Label.new()
	_status_label.position = Vector2(520, 18)
	_status_label.add_theme_font_size_override("font_size", 28)
	ui.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(430, 680)
	_hint_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(_hint_label)

	_on_player_hit_points_changed(player.hit_points)


func _update_ui() -> void:
	var time_left := maxf(0.0, BATTLE_LENGTH - _elapsed)
	_timer_label.text = "TIME %05.1f" % time_left

	if _state == "combat":
		if not player.counter_wave_enabled:
			_status_label.text = "SURVIVE"
			_hint_label.text = "WASD move  |  Space dash  |  LMB counter wave"
		elif player.get_cooldown_ratio() > 0.0:
			_status_label.text = "RECHARGING"
			_hint_label.text = "LMB sends a violet counter wave. R restarts."
		else:
			_status_label.text = "COUNTER READY"
			_hint_label.text = "LMB to cut safe lanes through enemy crests. R restarts."




