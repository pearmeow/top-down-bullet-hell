extends TileMapLayer

# Stay flat for half a second, then rise for one second before becoming dangerous.
const UNRAISED_DURATION := 0.5
const RISE_DURATION := 1.0
const RAISED_DURATION := 0.2
const RAISED_FRAME := 4
const SPIKE_SOURCE := 3
const SPIKE_ROW := 3

var cycle_time := 0.0
var current_frame := 0

func _physics_process(delta: float) -> void:
	cycle_time = fmod(cycle_time + delta, UNRAISED_DURATION + RISE_DURATION + RAISED_DURATION)
	var frame := 0
	if cycle_time >= UNRAISED_DURATION + RISE_DURATION:
		frame = RAISED_FRAME
	elif cycle_time >= UNRAISED_DURATION:
		frame = int((cycle_time - UNRAISED_DURATION) * RAISED_FRAME / RISE_DURATION)
	if frame == current_frame:
		return
	current_frame = frame
	for cell in get_used_cells():
		set_cell(cell, SPIKE_SOURCE, Vector2i(frame, SPIKE_ROW))
