class_name EncounterCatalog
extends RefCounted


static func get_encounter(encounter_id: String) -> Dictionary:
	match encounter_id:
		"mvp_combat_test":
			return _mvp_combat_test()
		_:
			push_error("Unknown encounter id: %s" % encounter_id)
			return _mvp_combat_test()


static func _mvp_combat_test() -> Dictionary:
	return {
		"id": "mvp_combat_test",
		"battle_length": 90.0,
		"game_speed": 0.333333,
		"kills_to_win": 3,
		"next_emitter_delay": 2.0,
		"player_position": Vector2(640, 570),
		"resonator_place_range": 190.0,
		"blue_beacon": {
			"name": "BlueBeacon",
			"position": Vector2(305, 515),
			"wave": {
				"speed": 190.0,
				"lifetime": 2.6,
				"max_radius": Wave.RED_MAX_RADIUS,
				"can_damage_emitters": false,
				"can_create_boost": false,
			},
		},
		"emitters": [
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
		],
	}
