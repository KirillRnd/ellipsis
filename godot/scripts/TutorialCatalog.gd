class_name TutorialCatalog
extends RefCounted


static func get_room_entry(room_index: int) -> Dictionary:
	match room_index:
		0:
			return {
				"id": "movement_and_red_front",
				"title": {"ru": "ДВИЖЕНИЕ И КРАСНЫЙ ФРОНТ", "en": "MOVEMENT AND THE RED FRONT"},
				"body": {
					"ru": "Двигайся с помощью WASD. Space — короткий рывок. Красный гребень наносит урон: уходи с его пути и доберись до открытого шлюза.",
					"en": "Move with WASD. Space performs a short dash. The red crest deals damage: evade its path and reach the open gate.",
				},
				"diagram": "movement",
			}
		1:
			return {
				"id": "friendly_safe_gap",
				"title": {"ru": "БЕЗОПАСНЫЙ РАЗРЫВ", "en": "SAFE GAP"},
				"body": {
					"ru": "Синяя волна не вредит Бесцветному. В месте её встречи с красным фронтом появляется светлый безопасный разрыв. Проходи через него.",
					"en": "A blue wave cannot harm the Colorless. Where it meets a red front, a bright safe gap appears. Pass through it.",
				},
				"diagram": "safe_gap",
			}
		3:
			return {
				"id": "blue_violet_resonance",
				"title": {"ru": "С/Ф РЕЗОНАНС", "en": "BLUE/VIOLET RESONANCE"},
				"body": {
					"ru": "Пересечение синей и фиолетовой волн создаёт С/Ф Резонанс. Яркий узел наносит цели значительно больше урона, чем обычная волна.",
					"en": "Intersecting blue and violet waves creates Blue/Violet Resonance. Its bright node deals far more damage than an ordinary wave.",
				},
				"diagram": "blue_violet",
			}
		_:
			return {}


static func get_pickup(kind: String) -> Dictionary:
	match kind:
		"resonator":
			return {
				"id": "first_violet_resonator",
				"title": {"ru": "РЕЗОНАТОР", "en": "RESONATOR"},
				"body": {
					"ru": "Резонатор — твой источник волн. E ставит его в точке курсора. Короткий ПКМ выпускает одну фиолетовую волну; удержание повторяет залпы.",
					"en": "The Resonator is your wave source. E places it at the cursor. Tap RMB for one violet wave; hold it for repeated volleys.",
				},
				"diagram": "resonator",
			}
		"resonator_capacity":
			return {
				"id": "violet_resonator_pair",
				"title": {"ru": "ДВА РЕЗОНАТОРА", "en": "TWO RESONATORS"},
				"body": {
					"ru": "Теперь доступны два Резонатора. Один ПКМ одновременно запускает оба. Пересечение двух фиолетовых волн создаёт Ф/Ф Резонанс — полностью управляемую тобой схему.",
					"en": "Two Resonators are now available. One RMB fires both. Two violet waves create Violet/Violet Resonance—a pattern entirely under your control.",
				},
				"diagram": "violet_pair",
			}
		"steel_crossbar":
			return {
				"id": "driven_crossbar",
				"title": {"ru": "КОВЫРЯЛКА", "en": "THE PRYING STICK"},
				"body": {
					"ru": "Ковырялка — вспомогательная защита, а не основное оружие. Короткий ЛКМ быстро вбивает клин. Удерживай ЛКМ, наведи и отпусти для более широкого и долгого разрыва.",
					"en": "The Prying Stick is a defensive aid, not a primary weapon. Tap LMB to drive a quick wedge. Hold LMB, aim, and release for a wider, longer gap.",
				},
				"diagram": "crossbar",
			}
		_:
			return {}
