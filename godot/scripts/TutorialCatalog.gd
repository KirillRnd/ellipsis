class_name TutorialCatalog
extends RefCounted


static func get_room_entry(room_index: int) -> Dictionary:
	match room_index:
		0:
			return {
				"id": "movement_and_red_front",
				"title": {"ru": "ДВИЖЕНИЕ И КРАСНАЯ ВОЛНА", "en": "MOVEMENT AND THE RED WAVE"},
				"body": {
					"ru": "Двигайся с помощью WASD. Space — короткий рывок. Гребень красной Волны наносит урон: уходи с его пути и доберись до открытого шлюза.",
					"en": "Move with WASD. Space performs a short dash. The crest of a red Wave deals damage: evade its path and reach the open gate.",
				},
				"diagram": "movement",
			}
		1:
			return {
				"id": "friendly_safe_gap",
				"title": {"ru": "ПОГАШЕНИЕ И БЕЗОПАСНЫЙ РАЗРЫВ", "en": "CANCELLATION AND SAFE GAP"},
				"body": {
					"ru": "Синяя Волна не вредит Бесцветному. При её встрече с красной Волной происходит Погашение: в опасном гребне появляется светлый безопасный разрыв.",
					"en": "A blue Wave cannot harm the Colorless. Where it meets a red Wave, Cancellation opens a bright safe gap in the dangerous crest.",
				},
				"diagram": "safe_gap",
			}
		3:
			return {
				"id": "blue_violet_resonance",
				"title": {"ru": "С/Ф РЕЗОНАНС", "en": "BLUE/VIOLET RESONANCE"},
				"body": {
					"ru": "Пересечение синей и фиолетовой Волн создаёт С/Ф Резонанс. Яркий узел Резонанса наносит цели значительно больше урона, чем обычная Волна.",
					"en": "Intersecting blue and violet Waves creates Blue/Violet Resonance. Its bright node deals far more damage than an ordinary Wave.",
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
					"ru": "Резонатор — твой источник Волн. E ставит Резонатор в точке курсора. Короткий ПКМ выпускает одну фиолетовую Волну; удержание повторяет залпы.",
					"en": "The Resonator is your Wave source. E places a Resonator at the cursor. Tap RMB for one violet Wave; hold it for repeated volleys.",
				},
				"diagram": "resonator",
			}
		"resonator_capacity":
			return {
				"id": "violet_resonator_pair",
				"title": {"ru": "ДВА РЕЗОНАТОРА", "en": "TWO RESONATORS"},
				"body": {
					"ru": "Теперь доступны два Резонатора. Один ПКМ одновременно запускает обе Волны. Их пересечение создаёт Ф/Ф Резонанс — полностью управляемую тобой схему.",
					"en": "Two Resonators are now available. One RMB fires both Waves. Their intersection creates Violet/Violet Resonance—a pattern entirely under your control.",
				},
				"diagram": "violet_pair",
			}
		"steel_crossbar":
			return {
				"id": "driven_crossbar",
				"title": {"ru": "КОВЫРЯЛКА", "en": "THE PRYING STICK"},
				"body": {
					"ru": "Ковырялка вызывает Погашение Волны. Короткий ЛКМ быстро вбивает клин. Удерживай ЛКМ, наведи и отпусти, чтобы создать более широкий и долгий безопасный разрыв.",
					"en": "The Prying Stick causes Wave Cancellation. Tap LMB to drive a quick wedge. Hold LMB, aim, and release to create a wider, longer safe gap.",
				},
				"diagram": "crossbar",
			}
		_:
			return {}
