class_name InterludeCatalog
extends RefCounted


const COLORLESS := "res://assets/interlude/characters/colorless.png"
const CRON := "res://assets/interlude/characters/cron.png"
const RAHN := "res://assets/interlude/characters/rahn.png"
const CROSSBAR := "res://assets/items/steel_crossbar_interlude.png"


static func get_for_room(room_index: int) -> Dictionary:
	match room_index:
		0:
			return {
				"id": "old_sluice_entry",
				"background": "res://assets/interlude/backgrounds/old_sluice_entry.png",
				"left": COLORLESS,
				"right": CRON,
				"messages": [
					{
						"speaker": {"en": "CRON", "ru": "КРОН"},
						"text": {
							"en": "The Old Sluice is still open, but red fronts have occupied its route.",
							"ru": "Старый Шлюз ещё открыт, но его маршрут заняли красные фронты.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "Then I cross it by reading the field, not by forcing it.",
							"ru": "Тогда я пройду, читая поле, а не продавливая его.",
						},
					},
				],
			}
		2:
			return {
				"id": "resonator_system",
				"background": "res://assets/interlude/backgrounds/resonator_system.png",
				"left": COLORLESS,
				"right": CRON,
				"messages": [
					{
						"speaker": {"en": "CRON", "ru": "КРОН"},
						"text": {
							"en": "A resonator is not a turret. You choose its support point and the moment it answers.",
							"ru": "Резонатор — не турель. Ты выбираешь точку опоры и момент ответа.",
						},
					},
					{
						"speaker": {"en": "CRON", "ru": "КРОН"},
						"text": {
							"en": "Place it with E. Command its wave with the right mouse button.",
							"ru": "Ставь его на E. Командуй волной правой кнопкой мыши.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "One point first. A pair when I can preserve the useful support.",
							"ru": "Сначала одна точка. Потом пара, если я сохраню полезную опору.",
						},
					},
				],
			}
		5:
			return {
				"id": "steel_crossbar",
				"background": "res://assets/interlude/backgrounds/steel_crossbar.png",
				"left": COLORLESS,
				"right": CROSSBAR,
				"right_is_item": true,
				"messages": [
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "Dead steel. It does not command magic; it makes the front go around.",
							"ru": "Мёртвый металл. Он не командует магией — он заставляет фронт обойти себя.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "A short drive for an emergency cut. Hold, aim and release for a wider gap.",
							"ru": "Короткий удар — для срочного разрыва. Удержать, навести и отпустить — для широкого прохода.",
						},
					},
				],
			}
		7:
			return {
				"id": "rahn_meeting",
				"background": "res://assets/interlude/backgrounds/rahn_meeting.png",
				"left": COLORLESS,
				"right": RAHN,
				"messages": [
					{
						"speaker": {"en": "RAHN", "ru": "РАХН"},
						"text": {
							"en": "You learned to hold two points. Now show me which one you can afford to lose.",
							"ru": "Ты научился держать две точки. Теперь покажи, какую можешь позволить себе потерять.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "The oldest leaves. The useful support remains.",
							"ru": "Старейшая уходит. Полезная опора остаётся.",
						},
					},
					{
						"speaker": {"en": "RAHN", "ru": "РАХН"},
						"text": {
							"en": "Then move.",
							"ru": "Тогда двигайся.",
						},
					},
				],
			}
		_:
			return {}
