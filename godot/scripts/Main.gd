extends Node2D

const DUNGEON_ID := "old_sluice_mvp"
const DEFAULT_BATTLE_LENGTH := 90.0
const DEFAULT_GAME_SPEED := 0.333333
const DEFAULT_KILLS_TO_WIN := 3
const DEFAULT_NEXT_EMITTER_DELAY := 2.0
const HUD_TOP_Y := 8.0
const HUD_SECOND_Y := 34.0
const HUD_BOTTOM_Y := 674.0
const HUD_TIMER_RECT := Rect2(Vector2(24, HUD_TOP_Y), Vector2(330, 28))
const HUD_CENTER_LABEL_RECT := Rect2(Vector2(360, HUD_TOP_Y), Vector2(560, 36))
const HUD_CONTROLS_RECT := Rect2(Vector2(70, HUD_BOTTOM_Y), Vector2(1140, 40))
const HINT_POPUP_SIZE := Vector2(760, 210)
const ENCOUNTER_CATALOG := preload("res://scripts/EncounterCatalog.gd")
const BLUE_BEACON_SCRIPT := preload("res://scripts/BlueBeacon.gd")
const RESONATOR_SCRIPT := preload("res://scripts/Resonator.gd")
const WAVE_EMITTER_SCENE := preload("res://scenes/WaveEmitter.tscn")
const EXIT_GATE_SCENE := preload("res://scenes/ExitGate.tscn")
const STEEL_CROSSBAR_DRIVEN_SCENE := preload("res://scenes/SteelCrossbarDriven.tscn")
const PICKUP_TEXTURE := preload("res://assets/items/pickup_white_glow.png")
const DEFAULT_RESONATOR_PLACE_RANGE := 190.0
const RESONATOR_PLACE_COOLDOWN := 0.55
const RESONATOR_VOLLEY_INTERVAL := 2.35 * 0.25
const MAX_ACTIVE_RESONATORS := 2
const PICKUP_VISUAL_HEIGHT := 64.0
const DEFAULT_LANGUAGE := "ru"
const SUPPORTED_LANGUAGES := ["ru", "en"]
const UI_TEXT := {
	"blue_source": {"en": "BLUE SOURCE", "ru": "СИНИЙ ИСТОЧНИК"},
	"controls": {"en": "WASD move | Space dash | LMB crossbar | E resonator | RMB volley | N/P rooms | F2 language | R retry", "ru": "WASD ходьба | Space рывок | ЛКМ поперечина | E резонатор | ПКМ залп | N/P комнаты | F2 язык | R повтор"},
	"counter_ready": {"en": "COUNTER READY", "ru": "КОНТРВОЛНА ГОТОВА"},
	"resonator_volley": {"en": "RESONATOR VOLLEY", "ru": "ЗАЛП РЕЗОНАТОРА"},
	"danger_node": {"en": "DANGER NODE", "ru": "ОПАСНЫЙ УЗЕЛ"},
	"defeat": {"en": "DEFEAT", "ru": "ПОРАЖЕНИЕ"},
	"demo_clear": {"en": "DEMO CLEAR", "ru": "ДЕМО ПРОЙДЕНО"},
	"exit_open": {"en": "EXIT OPEN", "ru": "ВЫХОД ОТКРЫТ"},
	"hp": {"en": "HP %d/30", "ru": "HP %d/30"},
	"reach_exit": {"en": "REACH THE EXIT", "ru": "ДОЙДИ ДО ВЫХОДА"},
	"hint_popup_footer": {"en": "Move, click, or wait to close", "ru": "Двигайся, кликни или подожди, чтобы закрыть"},
	"recharging": {"en": "RECHARGING", "ru": "ПЕРЕЗАРЯДКА"},
	"violet_emitter_pickup": {"en": "VIOLET EMITTER ACQUIRED", "ru": "ФИОЛЕТОВЫЙ ЭМИТТЕР ПОЛУЧЕН"},
	"resonator_pickup": {"en": "RESONATOR ACQUIRED", "ru": "РЕЗОНАТОР ПОЛУЧЕН"},
	"resonator_set": {"en": "RESONATOR SET", "ru": "РЕЗОНАТОР ПОСТАВЛЕН"},
	"room_clear_timer": {"en": "ROOM %d/%d  KILLS %d/%d", "ru": "КОМ %d/%d  ЦЕЛИ %d/%d"},
	"room_route_timer": {"en": "ROOM %d/%d  TIME %05.1f  EXIT", "ru": "КОМ %d/%d  ВРЕМЯ %05.1f  ВЫХОД"},
	"room_timer": {"en": "ROOM %d/%d  TIME %05.1f  KILLS %d/%d", "ru": "КОМ %d/%d  ВРЕМЯ %05.1f  ЦЕЛИ %d/%d"},
	"safe_lane": {"en": "SAFE LANE", "ru": "БЕЗОПАСНЫЙ ПРОХОД"},
	"survive": {"en": "SURVIVE", "ru": "ВЫЖИВАЙ"},
	"target_down": {"en": "TARGET DOWN", "ru": "ЦЕЛЬ УНИЧТОЖЕНА"},
}

@onready var wave_manager = $WaveManager
@onready var player = $Player
@onready var arena: Arena = $Arena

var _state := "combat"
var _elapsed := 0.0
var _kills := 0
var _next_emitter_index := 1
var _encounter_index := 0
var _restart_was_down := false
var _next_room_was_down := false
var _previous_room_was_down := false
var _language_was_down := false
var _language := DEFAULT_LANGUAGE
var _resonator_place_was_down := false
var _resonator_place_cooldown := 0.0
var _resonator_volley_was_down := false
var _resonator_volley_active := false
var _resonator_volley_cooldown := 0.0
var _dungeon_sequence: Array[String] = []
var _current_encounter := {}
var _scheduled_active_times: Array = []
var _blue_beacon
var _blue_beacon_wave_config := {}
var _battle_length := DEFAULT_BATTLE_LENGTH
var _kills_to_win := DEFAULT_KILLS_TO_WIN
var _next_emitter_delay := DEFAULT_NEXT_EMITTER_DELAY
var _resonator_place_range := DEFAULT_RESONATOR_PLACE_RANGE
var _objective := "defeat_emitters"
var _player_wave_available := true
var _dash_available := true
var _resonator_available := true
var _emitters: Array = []
var _resonators: Array[Resonator] = []
var _next_resonator_number := 1
var _driven_crossbar: SteelCrossbarDriven
var _exit_unlocked := false
var _exit_trigger_rect := Rect2()
var _exit_door_rect := Rect2()
var _exit_gate: ExitGate
var _hint_popup: Panel
var _hint_popup_title: Label
var _hint_popup_body: Label
var _hint_popup_footer: Label
var _hint_popup_left := 0.0
var _pickup_items: Array = []
var _timer_label: Label
var _hp_label: Label
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	wave_manager.player = player
	player.crossbar_action_started.connect(_on_player_crossbar_action_started)
	player.crossbar_drive_impact.connect(_on_player_crossbar_drive_impact)
	player.hit_points_changed.connect(_on_player_hit_points_changed)
	player.defeat_started.connect(_on_player_defeat_started)
	player.died.connect(_on_player_died)
	wave_manager.danger_changed.connect(_on_danger_changed)

	_create_exit_door_visual()
	_create_ui()

	_dungeon_sequence = ENCOUNTER_CATALOG.get_dungeon_sequence(DUNGEON_ID)
	_load_encounter(0)


func _load_encounter(index: int) -> void:
	_clear_current_encounter()
	_encounter_index = clampi(index, 0, max(0, _dungeon_sequence.size() - 1))
	var encounter_id := _dungeon_sequence[_encounter_index]
	_current_encounter = ENCOUNTER_CATALOG.get_encounter(encounter_id)
	_apply_encounter_settings(_current_encounter)

	_elapsed = 0.0
	_kills = 0
	_next_emitter_index = 1
	_state = "combat"
	_exit_unlocked = _objective == "reach_exit"
	player.counter_wave_enabled = _player_wave_available
	player.dash_enabled = _dash_available
	arena.set_background(_current_encounter.get("arena_background", "red_fault"))
	_set_exit_gate_open(_exit_unlocked)

	_create_emitters(_current_encounter.get("emitters", []))
	wave_manager.emitters = _emitters
	_scheduled_active_times.clear()
	for i in range(_emitters.size()):
		var emitter = _emitters[i]
		emitter.wave_manager = wave_manager
		_scheduled_active_times.append(emitter.active_at)
		emitter.defeated.connect(_on_emitter_defeated)

	_create_blue_beacon(_current_encounter.get("blue_beacon", {}))
	_create_pickups(_current_encounter.get("pickups", []))
	_show_room_hint_popup(_current_encounter.get("popup_hint", {}))
	_update_ui()


func _clear_current_encounter() -> void:
	for emitter in _emitters:
		if is_instance_valid(emitter):
			emitter.queue_free()
	_emitters.clear()

	if is_instance_valid(_blue_beacon):
		_blue_beacon.queue_free()
	_blue_beacon = null
	_blue_beacon_wave_config = {}

	for resonator in _resonators:
		if is_instance_valid(resonator):
			resonator.queue_free()
	_resonators.clear()
	_next_resonator_number = 1

	_clear_driven_crossbar()

	if is_instance_valid(wave_manager):
		wave_manager.clear_all_waves()

	for pickup in _pickup_items:
		var visual = pickup.get("visual")
		if is_instance_valid(visual):
			visual.queue_free()
	_pickup_items.clear()


func _apply_encounter_settings(encounter: Dictionary) -> void:
	Engine.time_scale = encounter.get("game_speed", DEFAULT_GAME_SPEED)
	_battle_length = encounter.get("battle_length", DEFAULT_BATTLE_LENGTH)
	_kills_to_win = encounter.get("kills_to_win", DEFAULT_KILLS_TO_WIN)
	_next_emitter_delay = encounter.get("next_emitter_delay", DEFAULT_NEXT_EMITTER_DELAY)
	_resonator_place_range = encounter.get("resonator_place_range", DEFAULT_RESONATOR_PLACE_RANGE)
	_resonator_place_was_down = Input.is_key_pressed(KEY_E)
	_resonator_place_cooldown = 0.0
	_resonator_volley_was_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_resonator_volley_active = false
	_resonator_volley_cooldown = 0.0
	_objective = encounter.get("objective", "defeat_emitters")
	_player_wave_available = encounter.get("player_wave_enabled", true)
	_dash_available = encounter.get("dash_enabled", true)
	_resonator_available = encounter.get("resonator_enabled", true)
	player.reset_for_encounter(encounter.get("player_position", player.global_position))
	player.counter_wave_enabled = _player_wave_available
	player.dash_enabled = _dash_available

	var exit_config: Dictionary = encounter.get("exit", {})
	_exit_door_rect = exit_config.get("door_rect", Rect2())
	_exit_trigger_rect = exit_config.get("trigger_rect", Rect2())


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
		emitter.wave_config = emitter_config.get("wave", {})
		emitter.damage_mode = emitter_config.get("damage_mode", emitter.damage_mode)
		add_child(emitter)
		_emitters.append(emitter)


func _on_player_crossbar_drive_impact(
	origin: Vector2,
	direction: Vector2,
	is_oriented: bool,
) -> void:
	_clear_driven_crossbar()
	_driven_crossbar = STEEL_CROSSBAR_DRIVEN_SCENE.instantiate()
	add_child(_driven_crossbar)
	_driven_crossbar.setup(origin, direction, is_oriented)
	wave_manager.set_driven_crossbar(_driven_crossbar)


func _on_player_crossbar_action_started(_animation_name: StringName) -> void:
	_clear_driven_crossbar()


func _clear_driven_crossbar() -> void:
	if is_instance_valid(wave_manager):
		wave_manager.set_driven_crossbar(null)
	if is_instance_valid(_driven_crossbar):
		_driven_crossbar.visible = false
		_driven_crossbar.queue_free()
	_driven_crossbar = null


func _create_pickups(pickup_configs: Array) -> void:
	for pickup_config in pickup_configs:
		var position: Vector2 = pickup_config.get("position", Vector2.ZERO)
		var size := Vector2(36, 36)
		var visual := Sprite2D.new()
		visual.name = pickup_config.get("name", "Pickup")
		visual.texture = PICKUP_TEXTURE
		visual.global_position = position
		var visual_scale := PICKUP_VISUAL_HEIGHT / float(PICKUP_TEXTURE.get_height())
		visual.scale = Vector2.ONE * visual_scale
		visual.z_index = 5
		add_child(visual)
		_pickup_items.append({
			"kind": pickup_config.get("kind", ""),
			"rect": Rect2(position - size * 0.75, size * 1.5),
			"visual": visual,
		})


func _update_pickups() -> void:
	for i in range(_pickup_items.size() - 1, -1, -1):
		var pickup: Dictionary = _pickup_items[i]
		var rect: Rect2 = pickup.get("rect", Rect2())
		if not rect.has_point(player.global_position):
			continue
		_apply_pickup(pickup.get("kind", ""))
		var visual = pickup.get("visual")
		if is_instance_valid(visual):
			visual.queue_free()
		_pickup_items.remove_at(i)


func _apply_pickup(kind: String) -> void:
	if kind == "violet_emitter":
		_player_wave_available = true
		player.counter_wave_enabled = true
		_status_label.text = _t("violet_emitter_pickup")
	elif kind == "resonator":
		_resonator_available = true
		_status_label.text = _t("resonator_pickup")


func _process(delta: float) -> void:
	_handle_restart()
	_handle_debug_room_navigation()
	_handle_language_toggle()
	_update_room_hint_popup(delta)
	if _state == "room_clear":
		_update_emitters(false)
		_update_blue_beacon(false)
		_handle_room_exit()
		_update_ui()
		return
	if _state != "combat":
		_update_emitters(false)
		_update_blue_beacon(false)
		return

	_elapsed += delta
	_resonator_place_cooldown = maxf(0.0, _resonator_place_cooldown - delta)
	_resonator_volley_cooldown = maxf(0.0, _resonator_volley_cooldown - delta)
	player.counter_wave_enabled = _player_wave_available
	player.dash_enabled = _dash_available
	_update_emitters(true)
	_update_blue_beacon(true)
	_update_pickups()
	_handle_resonator_input()
	if _objective == "reach_exit":
		_handle_room_exit()
	_update_ui()


func _handle_restart() -> void:
	var restart_down := Input.is_key_pressed(KEY_R)
	if restart_down and not _restart_was_down:
		_load_encounter(_encounter_index)
	_restart_was_down = restart_down


func _handle_debug_room_navigation() -> void:
	var next_down := Input.is_key_pressed(KEY_N)
	if next_down and not _next_room_was_down and _encounter_index + 1 < _dungeon_sequence.size():
		_load_encounter(_encounter_index + 1)
	_next_room_was_down = next_down

	var previous_down := Input.is_key_pressed(KEY_P)
	if previous_down and not _previous_room_was_down and _encounter_index > 0:
		_load_encounter(_encounter_index - 1)
	_previous_room_was_down = previous_down


func _handle_language_toggle() -> void:
	var language_down := Input.is_key_pressed(KEY_F2)
	if language_down and not _language_was_down:
		_cycle_language()
	_language_was_down = language_down


func _cycle_language() -> void:
	var current_index := SUPPORTED_LANGUAGES.find(_language)
	if current_index < 0:
		current_index = 0
	_language = SUPPORTED_LANGUAGES[(current_index + 1) % SUPPORTED_LANGUAGES.size()]
	_refresh_visible_text()


func _refresh_visible_text() -> void:
	if is_instance_valid(_hint_popup_footer):
		_hint_popup_footer.text = _t("hint_popup_footer")
	if is_instance_valid(_hint_popup) and _hint_popup.visible:
		_show_room_hint_popup(_current_encounter.get("popup_hint", {}))
	_update_ui()


func _handle_room_exit() -> void:
	if not _exit_unlocked:
		return
	if _exit_trigger_rect.has_point(player.global_position):
		if _encounter_index + 1 < _dungeon_sequence.size():
			_load_encounter(_encounter_index + 1)
		else:
			_set_state("victory")


func _unlock_exit() -> void:
	_state = "room_clear"
	_exit_unlocked = true
	player.counter_wave_enabled = false
	_update_emitters(false)
	_update_blue_beacon(false)
	wave_manager.clear_all_waves()
	_set_exit_gate_open(true)
	_status_label.text = _t("exit_open")
	_set_controls_text()


func _create_exit_door_visual() -> void:
	_exit_gate = EXIT_GATE_SCENE.instantiate()
	add_child(_exit_gate)


func _set_exit_gate_open(is_open: bool) -> void:
	if not is_instance_valid(_exit_gate):
		return
	_exit_gate.visible = _exit_door_rect.size.length_squared() > 0.0
	_exit_gate.configure(_exit_door_rect)
	_exit_gate.set_open(is_open)


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
	_blue_beacon.interval = config.get("interval", _blue_beacon.interval)
	_blue_beacon.initial_delay = config.get("initial_delay", _blue_beacon.initial_delay)
	_blue_beacon.active_at = config.get("active_at", _blue_beacon.active_at)
	_blue_beacon_wave_config = config.get("wave", {})
	_blue_beacon.fired_friendly_wave.connect(_on_blue_beacon_fired)
	add_child(_blue_beacon)


func _on_blue_beacon_fired(origin: Vector2) -> void:
	wave_manager.spawn_wave("player", "blue", origin, _blue_beacon_wave_config)
	_status_label.text = _t("blue_source")


func _handle_resonator_input() -> void:
	_advance_resonator_place_input(Input.is_key_pressed(KEY_E))
	_advance_resonator_volley_input(
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func _advance_resonator_place_input(resonator_place_down: bool) -> void:
	if (
		resonator_place_down
		and not _resonator_place_was_down
		and _resonator_available
		and _resonator_place_cooldown <= 0.0
	):
		if _place_resonator(_get_resonator_target_position()):
			_resonator_place_cooldown = RESONATOR_PLACE_COOLDOWN
	_resonator_place_was_down = resonator_place_down


func _advance_resonator_volley_input(resonator_volley_down: bool) -> void:
	if not resonator_volley_down:
		_resonator_volley_active = false
		_resonator_volley_was_down = false
		return

	if not _resonator_volley_was_down:
		_resonator_volley_active = (
			_resonator_volley_cooldown <= 0.0
			and _fire_resonator_volley()
		)
		if _resonator_volley_active:
			_resonator_volley_cooldown = RESONATOR_VOLLEY_INTERVAL
	elif _resonator_volley_active and _resonator_volley_cooldown <= 0.0:
		if _fire_resonator_volley():
			_resonator_volley_cooldown += RESONATOR_VOLLEY_INTERVAL
		else:
			_resonator_volley_active = false

	_resonator_volley_was_down = true


func _fire_resonator_volley() -> bool:
	_remove_invalid_resonators()
	if _resonators.is_empty():
		return false
	for resonator in _resonators:
		wave_manager.spawn_wave("player", "resonator", resonator.global_position)
		resonator.trigger()
	_status_label.text = _t("resonator_volley")
	return true


func _get_resonator_target_position() -> Vector2:
	var target: Vector2 = get_global_mouse_position()
	var offset: Vector2 = target - player.global_position
	if offset.length() > _resonator_place_range:
		target = player.global_position + offset.normalized() * _resonator_place_range
	return target.clamp(PlayerController.ARENA_RECT.position, PlayerController.ARENA_RECT.end)


func _place_resonator(target: Vector2) -> bool:
	_remove_invalid_resonators()
	if _resonators.size() >= MAX_ACTIVE_RESONATORS:
		var oldest_resonator: Resonator = _resonators.pop_front()
		if is_instance_valid(oldest_resonator):
			oldest_resonator.visible = false
			oldest_resonator.queue_free()

	var resonator: Resonator = RESONATOR_SCRIPT.new()
	resonator.name = "Resonator%d" % _next_resonator_number
	_next_resonator_number += 1
	resonator.global_position = target
	resonator.expired.connect(_on_resonator_expired)
	add_child(resonator)
	_resonators.append(resonator)
	player.play_action(&"place_resonator", target - player.global_position)
	_status_label.text = _t("resonator_set")
	return true


func _on_resonator_expired(resonator) -> void:
	_resonators.erase(resonator)


func _remove_invalid_resonators() -> void:
	for index in range(_resonators.size() - 1, -1, -1):
		if not is_instance_valid(_resonators[index]):
			_resonators.remove_at(index)


func _on_player_hit_points_changed(hit_points: int) -> void:
	if is_instance_valid(_hp_label):
		_hp_label.text = _t("hp") % max(hit_points, 0)


func _on_player_defeat_started() -> void:
	_set_state("defeat_transition")
	_clear_driven_crossbar()
	_resonator_volley_active = false
	if is_instance_valid(wave_manager):
		wave_manager.clear_all_waves()


func _on_player_died() -> void:
	_set_state("defeat")


func _on_emitter_defeated(_emitter) -> void:
	if _state != "combat":
		return
	_kills += 1
	if _objective != "defeat_emitters":
		_update_ui()
		return
	if _kills >= _kills_to_win:
		_unlock_exit()
		return
	_accelerate_next_scheduled_emitter()
	_status_label.text = _t("target_down")
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
		_status_label.text = _t("safe_lane")
	elif danger_value > 1:
		_status_label.text = _t("danger_node")


func _set_state(new_state: String) -> void:
	if _state == new_state:
		return
	_state = new_state
	player.counter_wave_enabled = false
	_set_exit_gate_open(false)
	if _state == "victory":
		_status_label.text = _t("demo_clear")
		_set_controls_text()
	elif _state == "defeat":
		_status_label.text = _t("defeat")
		_set_controls_text()


func _create_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	_timer_label = Label.new()
	_timer_label.position = HUD_TIMER_RECT.position
	_timer_label.size = HUD_TIMER_RECT.size
	_timer_label.clip_text = true
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 20)
	ui.add_child(_timer_label)

	_hp_label = Label.new()
	_hp_label.position = Vector2(24, HUD_SECOND_Y)
	_hp_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(_hp_label)

	_status_label = Label.new()
	_status_label.position = HUD_CENTER_LABEL_RECT.position
	_status_label.size = HUD_CENTER_LABEL_RECT.size
	_status_label.clip_text = true
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 26)
	ui.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.position = HUD_CONTROLS_RECT.position
	_hint_label.size = HUD_CONTROLS_RECT.size
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 16)
	ui.add_child(_hint_label)

	_create_hint_popup(ui)
	_on_player_hit_points_changed(player.hit_points)


func _create_hint_popup(ui: CanvasLayer) -> void:
	_hint_popup = Panel.new()
	_hint_popup.name = "RoomHintPopup"
	_hint_popup.size = HINT_POPUP_SIZE
	_hint_popup.position = (get_viewport_rect().size - HINT_POPUP_SIZE) * 0.5
	_hint_popup.visible = false
	_hint_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.023, 0.030, 0.86)
	style.border_color = Color(0.62, 0.82, 0.92, 0.72)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_hint_popup.add_theme_stylebox_override("panel", style)
	ui.add_child(_hint_popup)

	_hint_popup_title = Label.new()
	_hint_popup_title.position = Vector2(28, 22)
	_hint_popup_title.size = Vector2(HINT_POPUP_SIZE.x - 48, 30)
	_hint_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_popup_title.add_theme_font_size_override("font_size", 24)
	_hint_popup.add_child(_hint_popup_title)

	_hint_popup_body = Label.new()
	_hint_popup_body.position = Vector2(42, 68)
	_hint_popup_body.size = Vector2(HINT_POPUP_SIZE.x - 84, 92)
	_hint_popup_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_popup_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_popup_body.add_theme_font_size_override("font_size", 18)
	_hint_popup.add_child(_hint_popup_body)

	_hint_popup_footer = Label.new()
	_hint_popup_footer.position = Vector2(28, 172)
	_hint_popup_footer.size = Vector2(HINT_POPUP_SIZE.x - 56, 24)
	_hint_popup_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_popup_footer.text = _t("hint_popup_footer")
	_hint_popup_footer.add_theme_font_size_override("font_size", 14)
	_hint_popup.add_child(_hint_popup_footer)


func _show_room_hint_popup(config: Dictionary) -> void:
	if not is_instance_valid(_hint_popup):
		return
	var body := _localize(config.get("body", ""))
	if body.is_empty():
		_hint_popup.visible = false
		_hint_popup_left = 0.0
		return
	_hint_popup_title.text = _localize(config.get("title", _current_encounter.get("title", "")))
	_hint_popup_body.text = body
	_hint_popup_left = config.get("duration", 5.0)
	_hint_popup.visible = true


func _update_room_hint_popup(delta: float) -> void:
	if not is_instance_valid(_hint_popup) or not _hint_popup.visible:
		return
	_hint_popup_left -= delta
	if _hint_popup_left <= 0.0 or _room_hint_dismiss_input():
		_hint_popup.visible = false
		_hint_popup_left = 0.0


func _room_hint_dismiss_input() -> bool:
	return (
		Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_A)
		or Input.is_key_pressed(KEY_S)
		or Input.is_key_pressed(KEY_D)
		or Input.is_key_pressed(KEY_UP)
		or Input.is_key_pressed(KEY_DOWN)
		or Input.is_key_pressed(KEY_LEFT)
		or Input.is_key_pressed(KEY_RIGHT)
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_E)
		or Input.is_key_pressed(KEY_ENTER)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func _t(key: String) -> String:
	return _localize(UI_TEXT.get(key, key))


func _set_controls_text() -> void:
	if is_instance_valid(_hint_label):
		_hint_label.text = _t("controls")


func _localize(value) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var localized: Dictionary = value
		return str(localized.get(_language, localized.get(DEFAULT_LANGUAGE, localized.get("en", ""))))
	return str(value)


func _update_ui() -> void:
	if _state == "room_clear":
		_timer_label.text = _t("room_clear_timer") % [_encounter_index + 1, _dungeon_sequence.size(), _kills, _kills_to_win]
		_status_label.text = _t("exit_open")
		_set_controls_text()
		return

	var time_left := maxf(0.0, _battle_length - _elapsed)
	if _objective == "reach_exit":
		_timer_label.text = _t("room_route_timer") % [
			_encounter_index + 1,
			_dungeon_sequence.size(),
			time_left,
		]
	else:
		_timer_label.text = _t("room_timer") % [
			_encounter_index + 1,
			_dungeon_sequence.size(),
			time_left,
			_kills,
			_kills_to_win,
		]

	if _state == "combat":
		if _objective == "reach_exit":
			_status_label.text = _t("reach_exit")
		elif not _player_wave_available:
			_status_label.text = _t("survive")
		elif _resonator_volley_cooldown > 0.0:
			_status_label.text = _t("recharging")
		else:
			_status_label.text = _localize(_current_encounter.get("title", _t("counter_ready"))).to_upper()
		_set_controls_text()
