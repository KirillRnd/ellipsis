class_name AudioCatalog
extends Resource

@export var events: Array[SoundEvent] = []


func build_index() -> Dictionary:
	var result := {}
	for event in events:
		if event == null or event.event_id.is_empty():
			continue
		result[event.event_id] = event
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for index in range(events.size()):
		var event := events[index]
		if event == null:
			errors.append("Audio event %d is null" % index)
			continue
		if event.event_id.is_empty():
			errors.append("Audio event %d has an empty id" % index)
			continue
		if seen.has(event.event_id):
			errors.append("Duplicate audio event id: %s" % event.event_id)
		seen[event.event_id] = true
	return errors
