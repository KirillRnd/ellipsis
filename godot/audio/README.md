# Аудиосистема Ellipsis

`Audio` подключён как autoload из `scenes/audio/AudioRuntime.tscn`. Он держит
пулы глобальных и позиционных голосов, применяет cooldown и ограничения
конкурентности событий. `MusicDirector` переключает две музыкальные дорожки с
перекрёстным затуханием.

## Ресурсы

- `catalogs/main_sfx_catalog.tres` — реестр звуковых событий.
- `catalogs/main_music_catalog.tres` — реестр музыкальных cue.
- `events/` — настройки слоёв, шин, громкости, pitch и задержек.
- `music/` — точки запуска и параметры музыкальных композиций.
- `../assets/audio/` — runtime-файлы, импортируемые Godot.

Пустой `stream` у дополнительного `SoundLayer` допустим: это заготовка слоя,
которую `SoundLayer.should_play()` пропускает. У каждого события должен
оставаться хотя бы один назначенный проигрываемый слой.

## Музыка

В runtime используются только MP3:

- `The Idle Mechanism.mp3` — обычные диалоги, старт с 27,0 с;
- `Gears of the Gilded Age.mp3` — комнаты, старт с 0,0 с;
- `Crimson Steppe.mp3` — диалог с Рахном с 7,4 с и бой с 56,0 с;
- `The Clockwork Garden.mp3` — завершение демо, старт со 176,0 с.

Все cue имеют громкость `-5,036 dB`, fade `0,4 с` и зацикливаются от своей
точки запуска. При начале defeat-анимации Рана боевая музыка затихает за
`1,25 с`.

Исходные музыкальные WAV-мастера лежат в `../../music/2026-07-18/` и
отслеживаются Git LFS. Их не следует копировать в `assets/audio/music/`.

## Вызовы из кода

```gdscript
Audio.play_2d(&"wave.launch.red", global_position)
Audio.play_global(&"dialogue.voice.rahn")
Audio.play_music(&"rahn_battle")
Audio.set_bus_volume_linear(&"SFX", 0.8)
```

Новые события добавляются в SFX-каталог, новые музыкальные точки — в
music-каталог. Проверки находятся в `tests/audio_assets_smoke.gd` и
`tests/audio_runtime_smoke.gd`.

## Фонемы диалогов

Десять событий `dialogue.voice.*` направлены в шину `Dialogue`, вложенную в
`SFX`. `InterludeOverlay.gd` проигрывает фонему каждые 2–3 значимых символа,
не озвучивает пробелы и добавляет короткие паузы после пунктуации. Первый клик
раскрывает текущую строку, второй переходит к следующей.
