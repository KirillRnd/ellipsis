class_name SoundEvent
extends Resource

@export var event_id: StringName
@export var concurrency_group: StringName
@export_range(1, 64, 1) var max_instances := 4
@export_range(0, 10000, 1) var cooldown_ms := 0
@export_range(-100, 100, 1) var priority := 0
@export var steal_oldest := false
@export var layers: Array[SoundLayer] = []


func get_concurrency_key() -> StringName:
	return concurrency_group if not concurrency_group.is_empty() else event_id
