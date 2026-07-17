class_name EncounterCatalog
extends RefCounted


static func get_dungeon_sequence(dungeon_id: String) -> Array[String]:
	match dungeon_id:
		"old_sluice_mvp":
			return [
				"old_sluice_room_01_red_route",
				"old_sluice_room_02_blue_safe_route",
				"old_sluice_room_03_one_resonator",
				"old_sluice_room_04_blue_violet_resonance",
				"old_sluice_room_05_two_resonators",
				"old_sluice_room_06_crossbar",
				"old_sluice_room_07_red_pair",
				"old_sluice_room_08_rahn",
			]
		_:
			push_error("Unknown dungeon id: %s" % dungeon_id)
			return ["old_sluice_room_01_red_route"]


static func get_encounter(encounter_id: String) -> Dictionary:
	match encounter_id:
		"old_sluice_room_01_red_route", "old_sluice_room_01_red_reading":
			return _old_sluice_room_01_red_route()
		"old_sluice_room_02_blue_safe_route", "old_sluice_room_02_blue_gap":
			return _old_sluice_room_02_blue_safe_route()
		"old_sluice_room_03_one_resonator", "old_sluice_room_03_make_gap", "old_sluice_room_02_violet_cut":
			return _old_sluice_room_03_one_resonator()
		"old_sluice_room_04_blue_violet_resonance", "old_sluice_room_04_wave_dash", "old_sluice_room_03_dash_gate":
			return _old_sluice_room_04_blue_violet_resonance()
		"old_sluice_room_05_two_resonators", "old_sluice_room_05_active_emitter":
			return _old_sluice_room_05_two_resonators()
		"old_sluice_room_06_crossbar", "old_sluice_room_06_blue_resonance", "old_sluice_room_04_blue_gap":
			return _old_sluice_room_06_crossbar()
		"old_sluice_room_07_red_pair", "old_sluice_room_07_resonator", "old_sluice_room_05_resonator_geometry":
			return _old_sluice_room_07_red_pair()
		"old_sluice_room_08_rahn":
			return _old_sluice_room_08_rahn()
		"mvp_combat_test":
			return _mvp_combat_test()
		_:
			push_error("Unknown encounter id: %s" % encounter_id)
			return _old_sluice_room_01_red_route()


static func _base_room(id: String, title) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"objective": "defeat_emitters",
		"battle_length": 70.0,
		"game_speed": 0.333333,
		"arena_background": "red_fault",
		"kills_to_win": 1,
		"next_emitter_delay": 2.0,
		"player_position": Vector2(640, 570),
		"dash_enabled": true,
		"crossbar_enabled": false,
		"resonator_enabled": false,
		"resonator_limit": 1,
		"resonator_place_range": 190.0,
		"popup_hint": {
			"title": title,
			"body": "",
			"duration": 5.0,
		},
		"exit": {
			"side": "top",
			"door_rect": Rect2(Vector2(600, 60), Vector2(80, 26)),
			"trigger_rect": Rect2(Vector2(600, 90), Vector2(80, 38)),
		},
		"blue_beacon": {},
		"boss": {},
		"emitters": [],
	}


static func _small_red_wave(radius: float = 235.0) -> Dictionary:
	return {
		"lifetime": 4.2,
		"max_radius": radius,
	}


static func _old_sluice_room_01_red_route() -> Dictionary:
	var room := _base_room("old_sluice_room_01_red_route", {
		"en": "Room 1 - Red Route",
		"ru": "Комната 1 - красный маршрут",
	})
	room["objective"] = "reach_exit"
	room["battle_length"] = 70.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "No attack yet. Read the local red fronts and reach the open door.",
			"ru": "Атаки пока нет. Читай локальные красные фронты и дойди до открытой двери.",
		},
		"duration": 6.0,
	}
	room["emitters"] = [
		{
			"name": "RedRouteLeft",
			"position": Vector2(360, 205),
			"wave_kind": "red",
			"interval": 3.45,
			"initial_delay": 0.30,
			"active_at": 0.0,
			"damage_mode": "none",
			"wave": _small_red_wave(190.0),
		},
		{
			"name": "RedRouteMid",
			"position": Vector2(640, 370),
			"wave_kind": "red",
			"interval": 3.45,
			"initial_delay": 1.45,
			"active_at": 0.0,
			"damage_mode": "none",
			"wave": _small_red_wave(185.0),
		},
		{
			"name": "RedRouteRight",
			"position": Vector2(920, 205),
			"wave_kind": "red",
			"interval": 3.45,
			"initial_delay": 2.60,
			"active_at": 0.0,
			"damage_mode": "none",
			"wave": _small_red_wave(190.0),
		},
	]
	return room


static func _old_sluice_room_02_blue_safe_route() -> Dictionary:
	var room := _base_room("old_sluice_room_02_blue_safe_route", {
		"en": "Room 2 - Blue Safe Route",
		"ru": "Комната 2 - синий маршрут",
	})
	room["objective"] = "reach_exit"
	room["arena_background"] = "blue_guides"
	room["battle_length"] = 75.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "You still have no wave. Let the friendly blue source open safe space inside red.",
			"ru": "Своей волны всё ещё нет. Дай синему источнику открыть безопасное место внутри красного.",
		},
		"duration": 6.5,
	}
	room["blue_beacon"] = {
		"name": "BlueBeacon",
		"position": Vector2(480, 330),
		"interval": 3.0,
		"initial_delay": 0.0,
		"wave": {
			"lifetime": 7.2,
			"max_radius": Wave.RED_MAX_RADIUS,
			"can_damage_emitters": false,
			"can_create_resonance": false,
		},
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(800, 330),
			"wave_kind": "red",
			"interval": 3.0,
			"initial_delay": 0.0,
			"active_at": 0.0,
			"damage_mode": "none",
			"max_hit_points": 5,
			"wave": {
				"lifetime": 7.2,
				"max_radius": Wave.RED_MAX_RADIUS,
			},
		},
	]
	return room


static func _old_sluice_room_03_one_resonator() -> Dictionary:
	var room := _base_room("old_sluice_room_03_one_resonator", {
		"en": "Room 3 - One Resonator",
		"ru": "Комната 3 - один резонатор",
	})
	room["battle_length"] = 80.0
	room["resonator_enabled"] = false
	room["resonator_limit"] = 1
	room["resonator_place_range"] = 260.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Take the resonator. E places it; RMB fires one wave and held RMB repeats.",
			"ru": "Возьми резонатор. E ставит его, ПКМ даёт одну волну, удержание ПКМ повторяет залпы.",
		},
		"duration": 7.0,
	}
	room["pickups"] = [{
		"name": "FirstResonatorPickup",
		"kind": "resonator",
		"position": Vector2(640, 500),
	}]
	room["emitters"] = [{
		"name": "RedResonatorTarget",
		"position": Vector2(640, 185),
		"wave_kind": "red",
		"visual_kind": "resonator_red",
		"interval": 2.35,
		"initial_delay": 0.45,
		"active_at": 0.0,
		"damage_mode": "direct",
		"max_hit_points": 4,
	}]
	return room


static func _old_sluice_room_04_blue_violet_resonance() -> Dictionary:
	var room := _base_room("old_sluice_room_04_blue_violet_resonance", {
		"en": "Room 4 - Blue/Violet Resonance",
		"ru": "Комната 4 - сине-фиолетовый Резонанс",
	})
	room["battle_length"] = 85.0
	room["arena_background"] = "blue_guides"
	room["resonator_enabled"] = true
	room["resonator_limit"] = 1
	room["resonator_place_range"] = 280.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Cross your violet front with blue. The S/F Resonance deals much more damage.",
			"ru": "Пересеки свой фиолетовый фронт с синим. С/Ф Резонанс наносит намного больше урона.",
		},
		"duration": 7.0,
	}
	room["blue_beacon"] = {
		"name": "BlueBeacon",
		"position": Vector2(420, 340),
		"interval": 3.0,
		"initial_delay": 0.0,
		"wave": {
			"lifetime": 7.2,
			"max_radius": Wave.RED_MAX_RADIUS,
			"can_damage_emitters": false,
			"can_create_resonance": true,
		},
	}
	room["emitters"] = [{
		"name": "RedResonatorTarget",
		"position": Vector2(820, 340),
		"wave_kind": "red",
		"visual_kind": "resonator_red",
		"interval": 3.0,
		"initial_delay": 0.0,
		"active_at": 0.0,
		"damage_mode": "direct",
		"max_hit_points": 12,
		"wave": {
			"lifetime": 7.2,
			"max_radius": Wave.RED_MAX_RADIUS,
		},
	}]
	return room


static func _old_sluice_room_05_two_resonators() -> Dictionary:
	var room := _base_room("old_sluice_room_05_two_resonators", {
		"en": "Room 5 - Two Resonators",
		"ru": "Комната 5 - два резонатора",
	})
	room["battle_length"] = 90.0
	room["resonator_enabled"] = true
	room["resonator_limit"] = 1
	room["resonator_place_range"] = 280.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Take the second resonator. One RMB command fires both and creates F/F Resonance.",
			"ru": "Возьми второй резонатор. Одна команда ПКМ стреляет из обоих и создаёт Ф/Ф Резонанс.",
		},
		"duration": 7.0,
	}
	room["pickups"] = [{
		"name": "SecondResonatorPickup",
		"kind": "resonator_capacity",
		"position": Vector2(640, 500),
	}]
	room["emitters"] = [{
		"name": "RedResonatorTarget",
		"position": Vector2(640, 185),
		"wave_kind": "red",
		"visual_kind": "resonator_red",
		"interval": 2.6,
		"initial_delay": 0.4,
		"active_at": 0.0,
		"damage_mode": "direct",
		"max_hit_points": 14,
	}]
	return room


static func _old_sluice_room_06_crossbar() -> Dictionary:
	var room := _base_room("old_sluice_room_06_crossbar", {
		"en": "Room 6 - Steel Crossbar",
		"ru": "Комната 6 - Стальная Поперечина",
	})
	room["objective"] = "reach_exit"
	room["battle_length"] = 80.0
	room["resonator_enabled"] = true
	room["resonator_limit"] = 2
	room["crossbar_enabled"] = false
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Take the Crossbar. Short LMB cuts one front; hold and release LMB for a wider lasting gap.",
			"ru": "Возьми Поперечину. Короткий ЛКМ режет один фронт; удержи и отпусти ЛКМ для широкого долгого прохода.",
		},
		"duration": 7.5,
	}
	room["pickups"] = [{
		"name": "SteelCrossbarPickup",
		"kind": "steel_crossbar",
		"position": Vector2(640, 500),
	}]
	room["emitters"] = [{
		"name": "CrossbarPressure",
		"position": Vector2(640, 185),
		"wave_kind": "red",
		"visual_kind": "resonator_red",
		"interval": 1.85,
		"initial_delay": 0.55,
		"active_at": 0.0,
		"damage_mode": "none",
		"wave": _small_red_wave(430.0),
	}]
	return room


static func _old_sluice_room_07_red_pair() -> Dictionary:
	var room := _base_room("old_sluice_room_07_red_pair", {
		"en": "Room 7 - Red Pair",
		"ru": "Комната 7 - красная пара",
	})
	room["battle_length"] = 90.0
	room["kills_to_win"] = 2
	room["resonator_enabled"] = true
	room["resonator_limit"] = 2
	room["crossbar_enabled"] = true
	room["resonator_place_range"] = 280.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Two red resonators. Use your full scheme; no new rule is introduced here.",
			"ru": "Два красных резонатора. Используй всю свою схему — новых правил здесь нет.",
		},
		"duration": 6.0,
	}
	room["emitters"] = [
		{
			"name": "RedResonatorLeft",
			"position": Vector2(480, 185),
			"wave_kind": "red",
			"visual_kind": "resonator_red",
			"interval": 2.35,
			"initial_delay": 0.35,
			"active_at": 0.0,
			"damage_mode": "direct",
			"max_hit_points": 10,
		},
		{
			"name": "RedResonatorRight",
			"position": Vector2(800, 185),
			"wave_kind": "red",
			"visual_kind": "resonator_red",
			"interval": 2.35,
			"initial_delay": 1.50,
			"active_at": 0.0,
			"damage_mode": "direct",
			"max_hit_points": 10,
		},
	]
	return room


static func _old_sluice_room_08_rahn() -> Dictionary:
	var room := _base_room("old_sluice_room_08_rahn", {
		"en": "Room 8 - Red Driver Rahn",
		"ru": "Комната 8 - Красный Погонщик Рахн",
	})
	room["objective"] = "defeat_boss"
	room["battle_length"] = 120.0
	room["resonator_enabled"] = true
	room["resonator_limit"] = 2
	room["crossbar_enabled"] = true
	room["resonator_place_range"] = 280.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Rahn drives his own resonator pair. Read their FIFO replacement and answer with your full scheme.",
			"ru": "Рахн ведёт собственную пару резонаторов. Читай их FIFO-замену и отвечай всей своей схемой.",
		},
		"duration": 7.0,
	}
	room["boss"] = {
		"name": "RahnBoss",
		"position": Vector2(640, 190),
		"max_hit_points": 70,
		"move_speed": 185.0,
		"volley_interval": 2.35,
		"reposition_interval": 6.8,
	}
	return room


static func _mvp_combat_test() -> Dictionary:
	var room := _base_room("mvp_combat_test", {
		"en": "MVP Combat Test",
		"ru": "MVP боевой тест",
	})
	room["battle_length"] = 90.0
	room["arena_background"] = "gold_boss"
	room["kills_to_win"] = 3
	room["resonator_enabled"] = true
	room["resonator_limit"] = 2
	room["crossbar_enabled"] = true
	room["blue_beacon"] = {
		"name": "BlueBeacon",
		"position": Vector2(305, 515),
		"wave": {
			"lifetime": 2.6,
			"max_radius": Wave.RED_MAX_RADIUS,
			"can_damage_emitters": false,
			"can_create_resonance": false,
		},
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(355, 170),
			"wave_kind": "red",
			"interval": 2.25,
			"initial_delay": 0.35,
			"active_at": 0.0,
		},
		{
			"name": "RedEmitterB",
			"position": Vector2(925, 170),
			"wave_kind": "red",
			"interval": 2.6,
			"initial_delay": 0.75,
			"active_at": 30.0,
		},
		{
			"name": "GoldEmitter",
			"position": Vector2(640, 150),
			"wave_kind": "gold",
			"interval": 3.0,
			"initial_delay": 0.5,
			"active_at": 60.0,
		},
	]
	return room
