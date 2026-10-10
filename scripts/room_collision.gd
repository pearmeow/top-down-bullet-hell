extends Node2D

static var wall_tilesets: Dictionary = {}

func _ready() -> void:
	var walls := get_node_or_null("Walls") as TileMapLayer
	if walls == null or walls.tile_set == null:
		return
	var original := walls.tile_set
	var key := original.get_instance_id()
	if not wall_tilesets.has(key):
		var solid := original.duplicate(true) as TileSet
		if solid.get_physics_layers_count() == 0:
			solid.add_physics_layer()
		solid.set_physics_layer_collision_layer(0, 1)
		solid.set_physics_layer_collision_mask(0, 0)
		var half := Vector2(solid.tile_size) / 2.0
		var polygon := PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)])
		for index in solid.get_source_count():
			var source := solid.get_source(solid.get_source_id(index)) as TileSetAtlasSource
			if source == null:
				continue
			for tile_index in source.get_tiles_count():
				var coords := source.get_tile_id(tile_index)
				for alternative_index in source.get_alternative_tiles_count(coords):
					var alternative := source.get_alternative_tile_id(coords, alternative_index)
					var data := source.get_tile_data(coords, alternative)
					data.set_collision_polygons_count(0, 1)
					data.set_collision_polygon_points(0, 0, polygon)
		wall_tilesets[key] = solid
	walls.tile_set = wall_tilesets[key]
