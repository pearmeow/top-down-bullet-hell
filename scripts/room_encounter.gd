extends Node2D

var boss_room := false
const BOSS_ENEMY := preload("res://scenes/enemies/bone_warden.tscn")
const RANGED_ENEMY := preload("res://scenes/enemies/bone_caster.tscn")
const ENEMY := preload("res://scenes/enemies/skeleton.tscn")
const HORIZONTAL_GATE := preload("res://scenes/blockade/horizontal_spikes.tscn")
const VERTICAL_GATE := preload("res://scenes/blockade/vertical_spikes.tscn")
var player: CharacterBody2D
var hud: CanvasLayer
var room: Node2D
var exits: Array = []
var waves: Array[int] = [2, 3]
var active := false
var cleared := false
var wave_index: int = -1
var living: int = 0
var pending := false
var gates: Array[Node2D] = []
var enemies: Array[CharacterBody2D] = []
var grid := AStarGrid2D.new()
var safe_cells: Array[Vector2i] = []
var bounds: Rect2i
var floors: TileMapLayer

func configure(value: Node2D, target: CharacterBody2D, doors: Array, display: CanvasLayer, counts: Array[int]) -> void:
	add_to_group("encounters")
	room = value
	player = target
	exits = doors
	hud = display
	waves = counts
	floors = room.get_node("Floors") as TileMapLayer
	bounds = floors.get_used_rect()
	grid.region = bounds
	grid.cell_size = Vector2(16, 16)
	grid.offset = Vector2(8, 8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var safe := floors.get_cell_source_id(cell) != -1
			for layer_name in ["Walls", "Structures", "Pits", "Spikes"]:
				var layer := room.get_node_or_null(layer_name) as TileMapLayer
				if layer != null and layer.get_cell_source_id(cell) != -1:
					safe = false
			grid.set_point_solid(cell, not safe)
			if safe:
				safe_cells.append(cell)

func _physics_process(_delta: float) -> void:
	if cleared or active or not is_instance_valid(player) or player.dead or floors == null:
		return
	var interior := Rect2(Vector2(bounds.position) * 16.0, Vector2(bounds.size) * 16.0).grow(-32.0)
	var local := floors.to_local(player.global_position)
	if interior.has_point(local) and safe_cells.has(floors.local_to_map(local)):
		_begin()

func _begin() -> void:
	active = true
	_close_doors()
	_next_wave()

func _close_doors() -> void:
	for direction in exits:
		var horizontal: bool = direction.y != 0
		var gate := (HORIZONTAL_GATE if horizontal else VERTICAL_GATE).instantiate() as Node2D
		var tile := Vector2i.ZERO
		if direction == Vector2i.UP:
			tile.y = bounds.position.y + 1
		elif direction == Vector2i.DOWN:
			tile.y = bounds.end.y
		elif direction == Vector2i.LEFT:
			tile.x = bounds.position.x + 1
		else:
			tile.x = bounds.end.x
		gate.position = Vector2(tile) * 16.0
		room.add_child(gate)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(64, 16) if horizontal else Vector2(16, 64)
		shape.shape = rectangle
		shape.position = Vector2(0, -8) if horizontal else Vector2(-8, 0)
		body.add_child(shape)
		gate.add_child(body)
		gates.append(gate)
		var spikes := gate.get_node("WallSpikes") as TileMapLayer
		for spike_cell in spikes.get_used_cells():
			var world := spikes.to_global(spikes.map_to_local(spike_cell))
			var blocked_cell := floors.local_to_map(floors.to_local(world))
			if grid.is_in_boundsv(blocked_cell):
				grid.set_point_solid(blocked_cell, true)
				safe_cells.erase(blocked_cell)

func _next_wave() -> void:
	pending = false
	if not is_instance_valid(player) or player.dead:
		return
	wave_index += 1
	if wave_index >= waves.size():
		_finish()
		return
	living = 0
	enemies.clear()
	var candidates := safe_cells.duplicate()
	candidates.shuffle()
	for cell in candidates:
		if living >= waves[wave_index]:
			break
		var point := floors.to_global(floors.map_to_local(cell))
		var interior := Rect2(Vector2(bounds.position) * 16.0, Vector2(bounds.size) * 16.0).grow(-24.0)
		if not interior.has_point(floors.to_local(point)):
			continue
		if point.distance_to(player.global_position) < 80.0:
			continue
		if path_between(point, player.global_position).is_empty():
			continue
		var crowded := false
		for other in enemies:
			if point.distance_to(other.global_position) < 24.0:
				crowded = true
		if crowded:
			continue
		var enemy_scene := RANGED_ENEMY if waves[wave_index] >= 2 and living == waves[wave_index] - 1 else ENEMY
		if boss_room and wave_index == waves.size() - 1:
			enemy_scene = BOSS_ENEMY
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemy.encounter = self
		enemy.position = room.to_local(point)
		enemy.died.connect(_enemy_died)
		room.add_child(enemy)
		enemies.append(enemy)
		living += 1
	_update_status()
	if living == 0:
		_queue_wave()

func _enemy_died() -> void:
	living = maxi(0, living - 1)
	_update_status()
	if living == 0:
		_queue_wave()

func _queue_wave() -> void:
	if pending:
		return
	pending = true
	get_tree().create_timer(0.8).timeout.connect(_next_wave)

func _update_status() -> void:
	hud.set_encounter_text("Wave %d / %d  ·  %d remaining" % [wave_index + 1, waves.size(), living])

func _finish() -> void:
	if cleared:
		return
	cleared = true
	active = false
	for gate in gates:
		gate.queue_free()
	gates.clear()
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()
	var services := get_tree().current_scene.get_node_or_null("GameServices")
	if services != null:
		services.room_reward(room)
	hud.set_encounter_text("Room cleared · collect your reward")
	if boss_room:
		hud.show_victory()

func path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := floors.local_to_map(floors.to_local(from))
	var end := floors.local_to_map(floors.to_local(to))
	if not grid.is_in_boundsv(start) or grid.is_point_solid(start):
		return PackedVector2Array()
	if not grid.is_in_boundsv(end) or grid.is_point_solid(end):
		var distance := INF
		for cell in safe_cells:
			var candidate_distance := Vector2(cell).distance_squared_to(Vector2(end))
			if candidate_distance < distance:
				distance = candidate_distance
				end = cell
	var path := grid.get_point_path(start, end)
	for index in path.size():
		path[index] = floors.to_global(path[index])
	return path

func can_walk_direct(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 8.0))
	for index in range(steps + 1):
		var point := from.lerp(to, float(index) / float(steps))
		var cell := floors.local_to_map(floors.to_local(point))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
			return false
	return true
