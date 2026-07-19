class_name PhaseCursor
extends CanvasLayer

enum InputMode {
	MOUSE,
	GAMEPAD,
	TOUCH,
}

const CURSOR_TEXTURE := preload("res://assets/ui/cursor_phase_compass.png")
const MOUSE_SIZE := 54.0
const GAMEPAD_SIZE := 68.0
const TOUCH_SIZE := 78.0
const GAMEPAD_SPEED := 720.0
const TOUCH_MOUSE_GRACE := 0.18
const CURSOR_LAYER := 2000

var _visual: TextureRect
var _pointer_position := Vector2.ZERO
var _input_mode := InputMode.MOUSE
var _touch_active := false
var _touch_mouse_grace_left := 0.0


func _ready() -> void:
	# The phase cursor must remain readable above modal windows and every HUD layer.
	layer = CURSOR_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("phase_cursor")

	_visual = TextureRect.new()
	_visual.name = "Visual"
	_visual.texture = CURSOR_TEXTURE
	_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_visual)

	var viewport_size := get_viewport().get_visible_rect().size
	_pointer_position = get_viewport().get_mouse_position()
	if not Rect2(Vector2.ZERO, viewport_size).has_point(_pointer_position):
		_pointer_position = viewport_size * 0.5
	_apply_mode(InputMode.MOUSE)
	_update_visual_position()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and is_inside_tree():
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_active = event.pressed
		_touch_mouse_grace_left = TOUCH_MOUSE_GRACE
		_set_pointer_position(event.position)
		_apply_mode(InputMode.TOUCH)
	elif event is InputEventScreenDrag:
		_touch_active = true
		_touch_mouse_grace_left = TOUCH_MOUSE_GRACE
		_set_pointer_position(event.position)
		_apply_mode(InputMode.TOUCH)
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		if _touch_active or _touch_mouse_grace_left > 0.0:
			return
		_set_pointer_position(event.position)
		_apply_mode(InputMode.MOUSE)


func _process(delta: float) -> void:
	_touch_mouse_grace_left = maxf(0.0, _touch_mouse_grace_left - delta)
	var gamepad_direction := Input.get_vector(
		"cursor_left",
		"cursor_right",
		"cursor_up",
		"cursor_down"
	)
	if gamepad_direction.length_squared() > 0.01:
		_apply_mode(InputMode.GAMEPAD)
		_set_pointer_position(_pointer_position + gamepad_direction * GAMEPAD_SPEED * delta)


func get_world_position() -> Vector2:
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	return inverse_canvas * _pointer_position


func get_input_mode() -> InputMode:
	return _input_mode


func _set_pointer_position(value: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_pointer_position = value.clamp(Vector2.ZERO, viewport_size)
	_update_visual_position()


func _apply_mode(mode: InputMode) -> void:
	_input_mode = mode
	var display_size := MOUSE_SIZE
	match _input_mode:
		InputMode.GAMEPAD:
			display_size = GAMEPAD_SIZE
		InputMode.TOUCH:
			display_size = TOUCH_SIZE
	_visual.size = Vector2.ONE * display_size
	_visual.pivot_offset = _visual.size * 0.5
	_update_visual_position()


func _update_visual_position() -> void:
	if not is_instance_valid(_visual):
		return
	_visual.position = _pointer_position - _visual.size * 0.5
