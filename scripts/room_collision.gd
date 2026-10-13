extends Node2D

static var wall_tilesets: Dictionary = {}
var structure_rects: Array[Rect2] = []

func _ready() -> void:
	for layer_name in ["Walls", "Structures"]:
		_add_solid_collision(get_node_or_null(layer_name) as TileMapLayer)
	var structures := get_node_or_null("Structures") as TileMapLayer
	if structures != null:
		for cell in structures.get_used_cells():
			var data := structures.get_cell_tile_data(cell)
			if data == null or data.get_collision_polygons_count(0) == 0:
				continue
			var points := data.get_collision_polygon_points(0, 0)
			var rect := Rect2(points[0], Vector2.ZERO)
			for point in points:
				rect = rect.expand(point)
			rect.position += structures.map_to_local(cell)
			structure_rects.append(rect)

func _add_solid_collision(walls: TileMapLayer) -> void:
	if walls == null or walls.tile_set == null:
		return
	var original := walls.tile_set
	var key := str(original.get_instance_id(), ":", walls.name)
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
			var pixels := source.texture.get_image()
			for tile_index in source.get_tiles_count():
				var coords := source.get_tile_id(tile_index)
				for alternative_index in source.get_alternative_tiles_count(coords):
					var alternative := source.get_alternative_tile_id(coords, alternative_index)
					var data := source.get_tile_data(coords, alternative)
					var collision := polygon
					if walls.name == "Structures":
						var region := source.get_tile_texture_region(coords)
						var opaque := pixels.get_region(region).get_used_rect()
						if not opaque.has_area():
							continue
						var rect := Rect2(opaque)
						rect.position -= Vector2(region.size) / 2.0 + Vector2(data.texture_origin)
						collision = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
					data.set_collision_polygons_count(0, 1)
					data.set_collision_polygon_points(0, 0, collision)
		wall_tilesets[key] = solid
	walls.tile_set = wall_tilesets[key]

func is_structure_blocked(world: Vector2, margin: float = 0.0) -> bool:
	var structures := get_node_or_null("Structures") as TileMapLayer
	if structures == null:
		return false
	var point := structures.to_local(world)
	for rect in structure_rects:
		if rect.grow(margin).has_point(point):
			return true
	return false
