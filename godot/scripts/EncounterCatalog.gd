class_name EncounterCatalog
extends RefCounted


static func get_dungeon_sequence(dungeon_id: String) -> Array[String]:
	match dungeon_id:
		"old_sluice_mvp":
			return [
				"old_sluice_room_01_red_route",
				"old_sluice_room_02_blue_safe_route",
				"old_sluice_room_03_make_gap",
				"old_sluice_room_04_wave_dash",
				"old_sluice_room_05_active_emitter",
				"old_sluice_room_06_blue_resonance",
				"old_sluice_room_07_resonator",
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
		"old_sluice_room_03_make_gap", "old_sluice_room_02_violet_cut":
			return _old_sluice_room_03_make_gap()
		"old_sluice_room_04_wave_dash", "old_sluice_room_03_dash_gate":
			return _old_sluice_room_04_wave_dash()
		"old_sluice_room_05_active_emitter":
			return _old_sluice_room_05_active_emitter()
		"old_sluice_room_06_blue_resonance", "old_sluice_room_04_blue_gap":
			return _old_sluice_room_06_blue_resonance()
		"old_sluice_room_07_resonator", "old_sluice_room_05_resonator_geometry":
			return _old_sluice_room_07_resonator()
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
		"kills_to_win": 1,
		"next_emitter_delay": 2.0,
		"player_position": Vector2(640, 570),
		"player_wave_enabled": true,
		"dash_enabled": true,
		"resonator_enabled": false,
		"resonator_place_range": 190.0,
		"popup_hint": {
			"title": title,
			"body": "",
			"duration": 5.0,
		},
		"exit": {
			"side": "top",
			"door_rect": Rect2(Vector2(560, 60), Vector2(160, 26)),
			"trigger_rect": Rect2(Vector2(560, 90), Vector2(160, 38)),
			"color": Color(0.22, 0.86, 1.0, 0.78),
		},
		"blue_beacon": {},
		"emitters": [],
	}


static func _small_red_wave(radius: float = 235.0) -> Dictionary:
	return {
		"speed": 108.0,
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
	room["player_wave_enabled"] = false
	room["dash_enabled"] = false
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
			"position": Vector2(340, 210),
			"wave_kind": "red",
			"interval": 2.35,
			"initial_delay": 0.30,
			"active_at": 0.0,
			"wave": _small_red_wave(225.0),
		},
		{
			"name": "RedRouteMid",
			"position": Vector2(650, 255),
			"wave_kind": "red",
			"interval": 2.55,
			"initial_delay": 1.10,
			"active_at": 0.0,
			"wave": _small_red_wave(215.0),
		},
		{
			"name": "RedRouteRight",
			"position": Vector2(945, 210),
			"wave_kind": "red",
			"interval": 2.45,
			"initial_delay": 0.75,
			"active_at": 0.0,
			"wave": _small_red_wave(225.0),
		},
	]
	return room


static func _old_sluice_room_02_blue_safe_route() -> Dictionary:
	var room := _base_room("old_sluice_room_02_blue_safe_route", {
		"en": "Room 2 - Blue Safe Route",
		"ru": "Комната 2 - синий маршрут",
	})
	room["objective"] = "reach_exit"
	room["battle_length"] = 75.0
	room["player_wave_enabled"] = false
	room["dash_enabled"] = false
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
		"position": Vector2(365, 510),
		"interval": 2.9,
		"initial_delay": 0.35,
		"wave": {
			"speed": 180.0,
			"lifetime": 2.8,
			"max_radius": Wave.RED_MAX_RADIUS,
			"can_damage_emitters": false,
			"can_create_boost": false,
		},
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(760, 185),
			"wave_kind": "red",
			"interval": 2.25,
			"initial_delay": 0.35,
			"active_at": 0.0,
			"max_hit_points": 5,
		},
	]
	return room


static func _old_sluice_room_03_make_gap() -> Dictionary:
	var room := _base_room("old_sluice_room_03_make_gap", {
		"en": "Room 3 - Make The Gap",
		"ru": "Комната 3 - сделай проход",
	})
	room["objective"] = "reach_exit"
	room["battle_length"] = 75.0
	room["dash_enabled"] = false
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Now do it yourself. Fire violet into red and walk through the gap you made.",
			"ru": "Теперь сделай это сам. Пусти фиолетовую волну в красную и пройди через созданный разрыв.",
		},
		"duration": 6.5,
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(495, 185),
			"wave_kind": "red",
			"interval": 2.25,
			"initial_delay": 0.45,
			"active_at": 0.0,
			"max_hit_points": 4,
		},
	]
	return room


static func _old_sluice_room_04_wave_dash() -> Dictionary:
	var room := _base_room("old_sluice_room_04_wave_dash", {
		"en": "Room 4 - Wave And Dash",
		"ru": "Комната 4 - волна и рывок",
	})
	room["objective"] = "reach_exit"
	room["battle_length"] = 75.0
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Open a safe gap, then dash into it before the next red front closes the route.",
			"ru": "Открой safe gap и войди в него рывком, пока следующий красный фронт не закрыл маршрут.",
		},
		"duration": 6.5,
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(520, 170),
			"wave_kind": "red",
			"interval": 2.05,
			"initial_delay": 0.35,
			"active_at": 0.0,
			"max_hit_points": 4,
		},
		{
			"name": "RedEmitterB",
			"position": Vector2(825, 185),
			"wave_kind": "red",
			"interval": 2.55,
			"initial_delay": 1.10,
			"active_at": 8.0,
			"max_hit_points": 4,
		},
	]
	return room


static func _old_sluice_room_05_active_emitter() -> Dictionary:
	var room := _base_room("old_sluice_room_05_active_emitter", {
		"en": "Room 5 - Active Emitter",
		"ru": "Комната 5 - активный эмиттер",
	})
	room["battle_length"] = 80.0
	room["kills_to_win"] = 1
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "The violet wave is both shield and attack. Hit the active emitter with the wave front.",
			"ru": "Фиолетовая волна теперь и защита, и атака. Попади фронтом по активному эмиттеру.",
		},
		"duration": 6.5,
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(640, 185),
			"wave_kind": "red",
			"interval": 2.35,
			"initial_delay": 0.40,
			"active_at": 0.0,
			"max_hit_points": 4,
		},
	]
	return room


static func _old_sluice_room_06_blue_resonance() -> Dictionary:
	var room := _base_room("old_sluice_room_06_blue_resonance", {
		"en": "Room 6 - Blue Resonance",
		"ru": "Комната 6 - синий резонанс",
	})
	room["battle_length"] = 85.0
	room["kills_to_win"] = 1
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Friendly waves can resonate. Cross violet with blue to create a stronger point.",
			"ru": "Дружественные волны могут резонировать. Пересекай фиолетовую с синей, чтобы получить усиленную точку.",
		},
		"duration": 7.0,
	}
	room["blue_beacon"] = {
		"name": "BlueBeacon",
		"position": Vector2(330, 510),
		"interval": 2.8,
		"initial_delay": 0.35,
		"wave": {
			"speed": 190.0,
			"lifetime": 2.6,
			"max_radius": Wave.RED_MAX_RADIUS,
			"can_damage_emitters": false,
			"can_create_boost": true,
		},
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(835, 185),
			"wave_kind": "red",
			"interval": 2.4,
			"initial_delay": 0.40,
			"active_at": 0.0,
			"max_hit_points": 6,
		},
	]
	return room


static func _old_sluice_room_07_resonator() -> Dictionary:
	var room := _base_room("old_sluice_room_07_resonator", {
		"en": "Room 7 - Resonator",
		"ru": "Комната 7 - резонатор",
	})
	room["battle_length"] = 90.0
	room["kills_to_win"] = 2
	room["resonator_enabled"] = true
	room["resonator_place_range"] = 260.0
	room["player_position"] = Vector2(940, 570)
	room["popup_hint"] = {
		"title": room["title"],
		"body": {
			"en": "Place a resonator with RMB. LMB fires from you and from the resonator together.",
			"ru": "Поставь резонатор ПКМ. ЛКМ запускает волну от тебя и от резонатора одновременно.",
		},
		"duration": 7.0,
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(330, 180),
			"wave_kind": "red",
			"interval": 2.35,
			"initial_delay": 0.50,
			"active_at": 0.0,
			"max_hit_points": 5,
		},
		{
			"name": "RedEmitterB",
			"position": Vector2(720, 180),
			"wave_kind": "red",
			"interval": 2.75,
			"initial_delay": 1.15,
			"active_at": 10.0,
			"max_hit_points": 4,
		},
	]
	return room


static func _mvp_combat_test() -> Dictionary:
	var room := _base_room("mvp_combat_test", {
		"en": "MVP Combat Test",
		"ru": "MVP боевой тест",
	})
	room["battle_length"] = 90.0
	room["kills_to_win"] = 3
	room["resonator_enabled"] = true
	room["blue_beacon"] = {
		"name": "BlueBeacon",
		"position": Vector2(305, 515),
		"wave": {
			"speed": 190.0,
			"lifetime": 2.6,
			"max_radius": Wave.RED_MAX_RADIUS,
			"can_damage_emitters": false,
			"can_create_boost": false,
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
