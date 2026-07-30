class_name MusicCatalog
extends Resource

@export var cues: Array[MusicCue] = []


func build_index() -> Dictionary:
	var result := {}
	for cue in cues:
		if cue == null or cue.cue_id.is_empty():
			continue
		result[cue.cue_id] = cue
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for index in range(cues.size()):
		var cue := cues[index]
		if cue == null:
			errors.append("Music cue %d is null" % index)
			continue
		if cue.cue_id.is_empty():
			errors.append("Music cue %d has an empty id" % index)
			continue
		if cue.stream == null:
			errors.append("Music cue %s has no stream" % cue.cue_id)
		elif (
			cue.stream.get_length() > 0.0
			and cue.start_position_seconds >= cue.stream.get_length()
		):
			errors.append("Music cue %s starts beyond the end of its stream" % cue.cue_id)
		if seen.has(cue.cue_id):
			errors.append("Duplicate music cue id: %s" % cue.cue_id)
		seen[cue.cue_id] = true
	return errors
