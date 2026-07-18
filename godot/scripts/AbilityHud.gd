class_name AbilityHud
extends Control

const CROSSBAR_TEXTURE := preload("res://assets/items/steel_crossbar_topdown.png")
const RESONATOR_TEXTURE := preload("res://assets/actors/resonator_crystal_base.png")
const LMB_TEXTURE := preload("res://assets/ui/input_prompts/mouse_left.png")
const RMB_TEXTURE := preload("res://assets/ui/input_prompts/mouse_right.png")
const E_TEXTURE := preload("res://assets/ui/input_prompts/keyboard_e.png")

var _crossbar_slot: AbilitySlot
var _volley_slot: AbilitySlot
var _place_slot: AbilitySlot


func _ready() -> void:
	position = Vector2(968.0, 552.0)
	size = Vector2(292.0, 116.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crossbar_slot = _create_slot(Vector2(0.0, 0.0), LMB_TEXTURE, CROSSBAR_TEXTURE, "crossbar", "КОВЫРЯЛКА")
	_volley_slot = _create_slot(Vector2(98.0, 0.0), RMB_TEXTURE, null, "wave", "ВОЛНА")
	_place_slot = _create_slot(Vector2(196.0, 0.0), E_TEXTURE, RESONATOR_TEXTURE, "resonator", "РЕЗОНАТОР")


func set_state(
	crossbar_readiness: float,
	crossbar_enabled: bool,
	volley_readiness: float,
	volley_enabled: bool,
	place_readiness: float,
	place_enabled: bool,
	resonator_count: int,
	resonator_limit: int
) -> void:
	_crossbar_slot.set_state(crossbar_readiness, crossbar_enabled)
	_volley_slot.set_state(
		volley_readiness,
		volley_enabled,
		"%d/%d" % [resonator_count, resonator_limit]
	)
	_place_slot.set_state(place_readiness, place_enabled)


func set_language(language: String) -> void:
	if language == "en":
		_crossbar_slot.set_caption("CROSSBAR")
		_volley_slot.set_caption("WAVE")
		_place_slot.set_caption("RESONATOR")
	else:
		_crossbar_slot.set_caption("КОВЫРЯЛКА")
		_volley_slot.set_caption("ВОЛНА")
		_place_slot.set_caption("РЕЗОНАТОР")


func _create_slot(
	slot_position: Vector2,
	prompt: Texture2D,
	item: Texture2D,
	kind: String,
	caption: String
) -> AbilitySlot:
	var slot := AbilitySlot.new()
	slot.position = slot_position
	slot.size = Vector2(92.0, 108.0)
	add_child(slot)
	slot.configure(prompt, item, kind, caption)
	return slot
