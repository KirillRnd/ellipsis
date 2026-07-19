class_name MusicCue
extends Resource

@export var cue_id: StringName
@export var stream: AudioStream
@export var bus: StringName = &"Music"
@export_range(-80.0, 12.0, 0.1) var volume_db := 0.0
@export_range(0.0, 10.0, 0.05) var fade_seconds := 1.0
@export_range(0.0, 3600.0, 0.1) var start_position_seconds := 0.0
@export var loop_enabled := true
@export var restart_if_playing := false
