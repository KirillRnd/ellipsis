class_name EncounterCatalog
extends RefCounted


static func get_dungeon_sequence(dungeon_id: String) -> Array[String]:
	match dungeon_id:
		"old_sluice_mvp":
			return [
				"old_sluice_room_01_red_reading",
				"old_sluice_room_02_blue_gap",
			]
		_:
			push_error("Unknown dungeon id: %s" % dungeon_id)
			return ["old_sluice_room_01_red_reading"]


static func get_encounter(encounter_id: String) -> Dictionary:
	match encounter_id:
		"old_sluice_room_01_red_reading":
			return _old_sluice_room_01_red_reading()
		"old_sluice_room_02_blue_gap":
			return _old_sluice_room_02_blue_gap()
		"mvp_combat_test":
			return _mvp_combat_test()
		_:
			push_error("Unknown encounter id: %s" % encounter_id)
			return _old_sluice_room_01_red_reading()


static func _base_room(id: String, title) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"battle_length": 60.0,
		"game_speed": 0.333333,
		"kills_to_win": 1,
		"next_emitter_delay": 2.0,
		"player_position": Vector2(640, 570),
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


static func _old_sluice_room_01_red_reading() -> Dictionary:
	var room := _base_room("old_sluice_room_01_red_reading", {
		"en": "Room 1 - Red Reading",
		"ru": "Комната 1 - красные фронты",
	})
	room["popup_hint"] = {
		"title": {
			"en": "Room 1 - Red Reading",
			"ru": "Комната 1 - красные фронты",
		},
		"body": {
			"en": "Read the red wave front, move around it, then break the emitter.",
			"ru": "Читай красный фронт, обходи волну и затем сломай эмиттер.",
		},
		"duration": 5.5,
	}
	room["emitters"] = [
		{
			"name": "RedEmitterA",
			"position": Vector2(640, 190),
			"wave_kind": "red",
			"interval": 2.35,
			"initial_delay": 0.35,
			"active_at": 0.0,
			"max_hit_points": 4,
		},
	]
	return room


static func _old_sluice_room_02_blue_gap() -> Dictionary:
	var room := _base_room("old_sluice_room_02_blue_gap", {
		"en": "Room 2 - Blue Gap",
		"ru": "Комната 2 - синий проход",
	})
	room["battle_length"] = 75.0
	room["popup_hint"] = {
		"title": {
			"en": "Room 2 - Blue Gap",
			"ru": "Комната 2 - синий проход",
		},
		"body": {
			"en": "Blue is friendly. Use blue and violet waves to open a safe route through red.",
			"ru": "Синий цвет дружественный. Используй синие и фиолетовые волны, чтобы открыть безопасный путь через красное.",
		},
		"duration": 6.0,
	}
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
			"position": Vector2(760, 185),
			"wave_kind": "red",
			"interval": 2.25,
			"initial_delay": 0.35,
			"active_at": 0.0,
			"max_hit_points": 5,
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
