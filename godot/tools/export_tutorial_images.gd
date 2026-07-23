extends SceneTree

const OUTPUT_DIRECTORY := "res://../docs/tutorial_images"
const DIAGRAM_SIZE := Vector2(700.0, 330.0)
const EXPORT_SCALE := 2.0
const DIAGRAMS := [
	{"kind": "movement", "file": "01_movement_and_red_wave.png"},
	{"kind": "safe_gap", "file": "02_cancellation_and_safe_gap.png"},
	{"kind": "resonator", "file": "03_resonator.png"},
	{"kind": "blue_violet", "file": "04_blue_violet_resonance.png"},
	{"kind": "violet_pair", "file": "05_two_resonators.png"},
	{"kind": "crossbar", "file": "06_prying_stick_absorption.png"},
]


func _init() -> void:
	call_deferred("_export_all")


func _export_all() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_path)
	if directory_error != OK:
		push_error("Unable to create tutorial image directory: %s" % output_path)
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(DIAGRAM_SIZE * EXPORT_SCALE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var canvas := Control.new()
	canvas.size = DIAGRAM_SIZE
	canvas.scale = Vector2(EXPORT_SCALE, EXPORT_SCALE)
	viewport.add_child(canvas)

	var background := ColorRect.new()
	background.size = DIAGRAM_SIZE
	background.color = Color(0.025, 0.028, 0.035, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)

	var diagram := TutorialDiagram.new()
	diagram.size = DIAGRAM_SIZE
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(diagram)

	for config in DIAGRAMS:
		diagram.set_diagram_kind(config["kind"])
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var file_path: String = output_path.path_join(config["file"])
		var save_error := image.save_png(file_path)
		if save_error != OK:
			push_error("Unable to save tutorial image: %s" % file_path)
			quit(1)
			return
		print("Exported tutorial image: %s" % file_path)

	print("TUTORIAL IMAGE EXPORT OK: %d images" % DIAGRAMS.size())
	quit(0)
