extends TileMapLayer

func _ready() -> void:
	var cells := get_used_cells()
	# A separate static tileset keeps doorway locks raised without changing traps.
	tile_set = preload("res://assets/tileset/raised_spikes.tres")
	for cell in cells:
		set_cell(cell, 3, Vector2i(4, 3))
