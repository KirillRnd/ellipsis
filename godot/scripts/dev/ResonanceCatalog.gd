class_name ResonanceCatalog
extends RefCounted

const GAME_RESONATOR_VOLLEY_INTERVAL := 2.35 * 0.25
const GAME_WAVE_SPEED := 118.0
const GAME_CASCADE_SPACING := GAME_WAVE_SPEED * GAME_RESONATOR_VOLLEY_INTERVAL

const COLORS := [
	{"id": "violet", "symbol": "Ф", "ru": "Фиолетовый", "en": "Violet", "geometry": "circle", "color": Color("8d4bd6")},
	{"id": "blue", "symbol": "С", "ru": "Синий", "en": "Blue", "geometry": "circle", "color": Color("3979d2")},
	{"id": "cyan", "symbol": "Г", "ru": "Голубой", "en": "Cyan", "geometry": "circle", "color": Color("37a9d6")},
	{"id": "green", "symbol": "З", "ru": "Зелёный", "en": "Green", "geometry": "spiral", "color": Color("2f9054")},
	{"id": "yellow", "symbol": "Ж", "ru": "Жёлтый", "en": "Yellow", "geometry": "line", "color": Color("e0cf42")},
	{"id": "gold", "symbol": "G", "ru": "Золотой", "en": "Gold", "geometry": "line", "color": Color("c6a34a")},
	{"id": "red", "symbol": "К", "ru": "Красный", "en": "Red", "geometry": "circle", "color": Color("cf4f4f")},
]

const RESONANCES := {
	"0:0": {"id": "ff", "ru": "Лиссажу 2:1", "en": "Lissajous 2:1"},
	"0:1": {"id": "fs", "ru": "Проекция Лиссажу", "en": "Lissajous projection"},
	"1:1": {"id": "ss", "ru": "Рёбра Делоне", "en": "Delaunay edges"},
	"1:2": {"id": "sg", "ru": "Описанные окружности", "en": "Circumcircles"},
	"2:2": {"id": "gg", "ru": "Шестилепестковая розетка", "en": "Six-petal rosette"},
	"2:3": {"id": "zg", "ru": "Радиальный Фурье", "en": "Radial Fourier"},
	"3:3": {"id": "zz", "ru": "Листья Гиелиса", "en": "Gielis leaves"},
	"3:4": {"id": "yz", "ru": "Ветвящиеся кусты", "en": "Branching bushes"},
	"4:4": {"id": "yy", "ru": "Заполнение сектора", "en": "Sector fill"},
	"4:5": {"id": "gy", "ru": "Ромбическая сетка", "en": "Rhombic grid"},
	"5:5": {"id": "gold_gold", "ru": "Плитка Пенроуза", "en": "Penrose tiling"},
	"5:6": {"id": "kg", "ru": "Инфляционные звёзды", "en": "Inflation stars"},
	"6:6": {"id": "kk", "ru": "Динамический Вороной", "en": "Dynamic Voronoi"},
}


static func color_spec(index: int) -> Dictionary:
	return COLORS[clampi(index, 0, COLORS.size() - 1)]


static func pair_key(first: int, second: int) -> String:
	return "%d:%d" % [mini(first, second), maxi(first, second)]


static func resonance_spec(first: int, second: int) -> Dictionary:
	return RESONANCES.get(pair_key(first, second), {})


static func can_resonate(first: int, second: int) -> bool:
	return absi(first - second) <= 1


static func resonance_color(first: int, second: int) -> Color:
	var a: Color = color_spec(first)["color"]
	var b: Color = color_spec(second)["color"]
	if first == second:
		return a.lightened(0.28)
	return a.lerp(b, 0.5).lightened(0.10)
