class_name SoundLayer
extends Resource

@export var display_name: StringName = &"Layer"
@export var stream: AudioStream
@export var bus: StringName = &"SFX"
@export_range(-80.0, 12.0, 0.1) var volume_db := 0.0
@export_range(0.0, 12.0, 0.1) var random_volume_db := 0.0
@export_range(0.25, 4.0, 0.01) var pitch_min := 1.0
@export_range(0.25, 4.0, 0.01) var pitch_max := 1.0
@export_range(0.0, 5.0, 0.001) var delay_min_seconds := 0.0
@export_range(0.0, 5.0, 0.001) var delay_max_seconds := 0.0
@export_range(0.0, 1.0, 0.01) var probability := 1.0
@export_range(32.0, 4096.0, 1.0) var max_distance := 1400.0
@export_range(0.0, 8.0, 0.05) var attenuation := 1.0


func should_play() -> bool:
	return stream != null and (probability >= 1.0 or randf() <= probability)


func choose_volume_db() -> float:
	return volume_db + randf_range(-random_volume_db, random_volume_db)


func choose_pitch() -> float:
	var low := minf(pitch_min, pitch_max)
	var high := maxf(pitch_min, pitch_max)
	return randf_range(low, high)


func choose_delay_seconds() -> float:
	var low := minf(delay_min_seconds, delay_max_seconds)
	var high := maxf(delay_min_seconds, delay_max_seconds)
	return randf_range(low, high)
