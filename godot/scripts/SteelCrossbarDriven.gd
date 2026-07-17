class_name SteelCrossbarDriven
extends Node2D

const SHORT_LIFETIME := 0.72
const LONG_LIFETIME := 2.70
const SHORT_MAX_FRONTS := 1
const LONG_MAX_FRONTS := 3
const CONTACT_RADIUS := 18.0
const MIN_GAP_WIDTH := 112.0
const MAX_GAP_WIDTH := 176.0

var placement_direction := Vector2.UP
var is_oriented := false
var lifetime := SHORT_LIFETIME
var max_fronts := SHORT_MAX_FRONTS
var age := 0.0
var _processed_wave_ids := {}


func setup(origin: Vector2, direction: Vector2, oriented: bool) -> void:
	global_position = origin
	placement_direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.UP
	is_oriented = oriented
	lifetime = LONG_LIFETIME if is_oriented else SHORT_LIFETIME
	max_fronts = LONG_MAX_FRONTS if is_oriented else SHORT_MAX_FRONTS
	age = 0.0
	_processed_wave_ids.clear()
	rotation = placement_direction.angle() + PI * 0.5


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()


func can_affect_wave(wave) -> bool:
	if not is_instance_valid(wave):
		return false
	var wave_id = wave.get_instance_id()
	return _processed_wave_ids.has(wave_id) or _processed_wave_ids.size() < max_fronts


func mark_wave_processed(wave) -> void:
	if not is_instance_valid(wave):
		return
	_processed_wave_ids[wave.get_instance_id()] = true


func get_gap_width(front_tangent: Vector2) -> float:
	if not is_oriented or front_tangent.length_squared() <= 0.0:
		return MIN_GAP_WIDTH
	var alignment := absf(placement_direction.dot(front_tangent.normalized()))
	return lerpf(MIN_GAP_WIDTH, MAX_GAP_WIDTH, alignment)
