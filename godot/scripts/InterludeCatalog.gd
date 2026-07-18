class_name InterludeCatalog
extends RefCounted


const COLORLESS := "res://assets/interlude/characters/colorless.png"
const CRON := "res://assets/interlude/characters/cron.png"
const RAHN := "res://assets/interlude/characters/rahn.png"


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
							"en": "Colorless, the Old Sluice has been seized by the Reds. The Blue Guides retreated behind the inner gates.",
							"ru": "Бесцветный, Старый Шлюз захвачен Красными. Синие Проводники отступили за внутренние ворота.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "Cron, if the passage still holds, I will find a way through.",
							"ru": "Крон, если проход ещё держится, я найду дорогу.",
						},
					},
					{
						"speaker": {"en": "CRON", "ru": "КРОН"},
						"text": {
							"en": "Then do not linger. The red light has already reached the old beacons.",
							"ru": "Тогда не задерживайся. Красный свет уже добрался до старых маяков.",
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
							"en": "These Resonators belonged to the Blues long before the fall of the Old Sluice.",
							"ru": "Эти Резонаторы принадлежали Синим задолго до падения Старого Шлюза.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "And yet one of them answers to the Colorless.",
							"ru": "И всё же один из них откликается на Бесцветного.",
						},
					},
					{
						"speaker": {"en": "CRON", "ru": "КРОН"},
						"text": {
							"en": "Take it. The Reds left us no time to unravel miracles.",
							"ru": "Возьми его. Красные не оставили нам времени разбираться в чудесах.",
						},
					},
				],
			}
		5:
			return {
				"id": "steel_crossbar",
				"background": "res://assets/interlude/backgrounds/steel_crossbar.png",
				"left": COLORLESS,
				"right": CRON,
				"messages": [
					{
						"speaker": {"en": "CRON", "ru": "КРОН"},
						"text": {
							"en": "The Blues pulled this steel crossbar from the Old Sluice gates after the Fall.",
							"ru": "Эту стальную поперечину Синие вынули из ворот Старого Шлюза после Падения.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "A grand past for a piece of iron. I will call it the Prying Stick.",
							"ru": "Слишком громкое прошлое для куска железа. Будет Ковырялкой.",
						},
					},
					{
						"speaker": {"en": "CRON", "ru": "КРОН"},
						"text": {
							"en": "Call it what you like. Just do not lose it before you meet Rahn.",
							"ru": "Назови как хочешь. Только не потеряй её до встречи с Рахном.",
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
							"en": "Colorless. Cron did bring you to the heart of the Old Sluice after all.",
							"ru": "Бесцветный. Крон всё-таки довёл тебя до сердца Старого Шлюза.",
						},
					},
					{
						"speaker": {"en": "COLORLESS", "ru": "БЕСЦВЕТНЫЙ"},
						"text": {
							"en": "Stand aside, Rahn. I want no war with the Reds.",
							"ru": "Отойди, Рахн. Мне не нужна война с Красными.",
						},
					},
					{
						"speaker": {"en": "RAHN", "ru": "РАХН"},
						"text": {
							"en": "The Reds do not need your consent. Set your Resonators; let us see what the Blues taught you.",
							"ru": "А Красным не нужно твоё согласие. Ставь Резонаторы — посмотрим, чему научили тебя Синие.",
						},
					},
				],
			}
		_:
			return {}
