extends Node2D

## -1 chooses a new seed on every launch; set a seed to replay a layout.
@export var level_seed: int = -1
@export var playtest_mode := false

const GRID_WIDTH := 8
const GRID_HEIGHT := 6
const CELL_WIDTH := 42
const CELL_HEIGHT := 42
const MAIN_PATH_ROOMS := 16
const SIDE_BRANCHES := 3
const COPIES_PER_ROOM := 2
const BOSS_HALL_GAP := 6
const TILE_SIZE := 16
const ENCOUNTER_SCRIPT := preload("res://scripts/room_encounter.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const NORTH := Vector2i.UP
const SOUTH := Vector2i.DOWN
const WEST := Vector2i.LEFT
const EAST := Vector2i.RIGHT
const START_CELL := Vector2i(3, 2)

const START_SCENE := preload("res://scenes/rooms/start.tscn")
const SHOP_SCENE := preload("res://scenes/rooms/shop.tscn")
const BOSS_SCENE := preload("res://scenes/rooms/boss_room.tscn")
const BIG_SCENE := preload("res://scenes/rooms/big_room.tscn")
const PITS_AND_SPIKES_SCENE := preload("res://scenes/rooms/pits_and_spikes_room.tscn")
const PITS_SCENE := preload("res://scenes/rooms/pits_room.tscn")
const SHOOTING_SCENE := preload("res://scenes/rooms/shooting_room.tscn")
const SPIKE_SCENE := preload("res://scenes/rooms/spike_room.tscn")
const THIN_SCENE := preload("res://scenes/rooms/thin_room.tscn")
const WALLS_AND_SPIKES_SCENE := preload("res://scenes/rooms/walls_and_spikes_room.tscn")
const WALLS_SCENE := preload("res://scenes/rooms/walls_room.tscn")

const HALL_HORIZONTAL := preload("res://scenes/connectors/horizontal_hall.tscn")
const HALL_VERTICAL := preload("res://scenes/connectors/vertical_hall.tscn")
const BLOCK_UP := preload("res://scenes/blockade/up.tscn")
const BLOCK_DOWN := preload("res://scenes/blockade/down.tscn")
const BLOCK_LEFT := preload("res://scenes/blockade/left.tscn")
const BLOCK_RIGHT := preload("res://scenes/blockade/right.tscn")

var rng := RandomNumberGenerator.new()
var generated_seed: int
var edges: Array[Dictionary] = []
var main_path: Array[Vector2i] = []
var branch_cells: Array[Vector2i] = []
var shop_cell: Vector2i
var boss_cell: Vector2i
var boss_entrance_cell: Vector2i
var boss_origin_y: int
var rooms: Dictionary = {}
var openings: Dictionary = {}
var room_scenes: Dictionary = {}
var occupied_tiles: Dictionary = {}
var services: Node2D
var player: CharacterBody2D


func _ready() -> void:
	_setup_player_input()
	if level_seed == -1:
		rng.randomize()
	else:
		rng.seed = level_seed
	generated_seed = rng.seed
	print("Level seed: ", generated_seed)
	_generate_layout()
	for edge in edges:
		_register_opening(edge.a, edge.b - edge.a)
		_register_opening(edge.b, edge.a - edge.b)
	_assign_room_scenes()
	for cell in main_path:
		if cell != boss_cell:
			_create_room(cell)
	for cell in branch_cells:
		_create_room(cell)
	_create_room(boss_cell)
	for edge in edges:
		_connect(edge.a, edge.b)
	for cell in rooms:
		_cap_unused_openings(cell)
	_spawn_player()
	$CombatHUD.bind_player(player)
	_setup_encounters()
	services = Node2D.new()
	services.set_script(preload("res://scripts/game_services.gd"))
	services.name = "GameServices"
	add_child(services)
	services.configure(self)


func _process(_delta: float) -> void:
	if is_instance_valid(player):
		$Camera2D.global_position = player.global_position


func _setup_player_input() -> void:
	var bindings := {
		"move_left": KEY_A, "move_right": KEY_D,
		"move_up": KEY_W, "move_down": KEY_S, "dodge": KEY_SPACE, "interact": KEY_E, "cancel_shop": KEY_ESCAPE,
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", click)


func _spawn_player() -> void:
	var start_room: Node2D = rooms[START_CELL]
	var floors := start_room.get_node("Floors") as TileMapLayer
	var candidates := floors.get_used_cells()
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	var spawn_tile := Vector2i.ZERO
	for cell in candidates:
		var safe := true
		for layer_name in ["Walls", "Structures", "Pits", "Spikes"]:
			var layer := start_room.get_node_or_null(layer_name) as TileMapLayer
			if layer != null and layer.get_cell_source_id(cell) != -1:
				safe = false
		if safe:
			spawn_tile = cell
			break
	player = PLAYER_SCENE.instantiate() as CharacterBody2D
	if playtest_mode:
		player.max_health = 10
		player.coins = 30
	add_child(player)
	player.global_position = floors.to_global(floors.map_to_local(spawn_tile))
	$Camera2D.global_position = player.global_position


## A randomized depth-first walk creates a long, self-avoiding main route.
## Short branches from its interior become the optional dead ends.
func _generate_layout() -> void:
	for attempt in 500:
		edges.clear()
		main_path.clear()
		branch_cells.clear()
		# These columns allow the fixed-length route to reach the room below the boss.
		boss_cell = Vector2i(2 if rng.randi_range(0, 1) == 0 else 6, 0)
		boss_entrance_cell = boss_cell + SOUTH
		main_path.append(START_CELL)
		var used: Dictionary = {START_CELL: true}
		if not _extend_main_path(used, MAIN_PATH_ROOMS - 1):
			continue
		main_path.append(boss_cell)
		used[boss_cell] = true
		var branch_options: Array[Dictionary] = []
		for index in range(2, main_path.size() - 2):
			var anchor := main_path[index]
			for neighbor in _shuffled_neighbors(anchor):
				if not used.has(neighbor) and _is_isolated_leaf(neighbor, anchor, used):
					branch_options.append({"anchor": anchor, "cell": neighbor, "index": index})
		if branch_options.size() < SIDE_BRANCHES:
			continue
		_shuffle(branch_options)
		branch_cells.clear()
		var branch_anchors: Dictionary = {}
		var branch_indices: Array[int] = []
		for option in branch_options:
			if branch_cells.size() == SIDE_BRANCHES:
				break
			if used.has(option.cell) or branch_anchors.has(option.anchor):
				continue
			var too_close := false
			for previous in branch_indices:
				if absi(option.index - previous) < 2:
					too_close = true
					break
			if too_close:
				continue
			if not _is_isolated_leaf(option.cell, option.anchor, used):
				continue
			branch_cells.append(option.cell)
			branch_anchors[option.anchor] = true
			branch_indices.append(option.index)
			used[option.cell] = true
		if branch_cells.size() != SIDE_BRANCHES:
			continue
		# A shop is one of the optional dead ends, so it appears exactly once.
		shop_cell = branch_cells[rng.randi_range(0, branch_cells.size() - 1)]
		for index in range(main_path.size() - 1):
			edges.append({"a": main_path[index], "b": main_path[index + 1]})
		for branch in branch_cells:
			for option in branch_options:
				if option.cell == branch and branch_anchors.has(option.anchor):
					edges.append({"a": option.anchor, "b": branch})
					branch_anchors.erase(option.anchor)
					break
		if _has_required_room_slots():
			return
	assert(false, "Could not build a route with slots for every room type")


func _has_required_room_slots() -> bool:
	var exits: Dictionary = {}
	for edge in edges:
		for cell in [edge.a, edge.b]:
			if not exits.has(cell):
				exits[cell] = []
		exits[edge.a].append(edge.b - edge.a)
		exits[edge.b].append(edge.a - edge.b)
	var vertical_slots := 0
	var horizontal_slots := 0
	for cell in exits:
		if cell == START_CELL or cell == boss_cell or cell == shop_cell:
			continue
		var required: Array = exits[cell]
		if not required.has(EAST) and not required.has(WEST):
			vertical_slots += 1
		if not required.has(NORTH) and not required.has(SOUTH):
			horizontal_slots += 1
	return vertical_slots >= COPIES_PER_ROOM and horizontal_slots >= COPIES_PER_ROOM


func _extend_main_path(used: Dictionary, target: int) -> bool:
	if main_path.size() == target:
		return main_path.back() == boss_entrance_cell
	var steps_left := target - main_path.size()
	var distance := absi(main_path.back().x - boss_entrance_cell.x) + absi(main_path.back().y - boss_entrance_cell.y)
	if distance > steps_left or (steps_left - distance) % 2 != 0:
		return false
	for neighbor in _shuffled_neighbors(main_path.back()):
		if used.has(neighbor):
			continue
		if neighbor == boss_entrance_cell and main_path.size() != target - 1:
			continue
		used[neighbor] = true
		main_path.append(neighbor)
		if _extend_main_path(used, target):
			return true
		main_path.pop_back()
		used.erase(neighbor)
	return false


func _shuffled_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in [NORTH, SOUTH, WEST, EAST]:
		var neighbor: Vector2i = cell + direction
		if neighbor.x >= 0 and neighbor.x < GRID_WIDTH and neighbor.y > 0 and neighbor.y < GRID_HEIGHT \
				and (neighbor.x != boss_cell.x or neighbor == boss_entrance_cell):
			result.append(neighbor)
	_shuffle(result)
	return result


func _shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var item = items[index]
		items[index] = items[other]
		items[other] = item


func _is_isolated_leaf(cell: Vector2i, anchor: Vector2i, used: Dictionary) -> bool:
	for neighbor in _shuffled_neighbors(cell):
		if neighbor != anchor and used.has(neighbor):
			return false
	return true


func _register_opening(cell: Vector2i, direction: Vector2i) -> void:
	if not openings.has(cell):
		openings[cell] = []
	openings[cell].append(direction)


func _assign_room_scenes() -> void:
	var vertical_slots: Array[Vector2i] = []
	var horizontal_slots: Array[Vector2i] = []
	for cell in openings:
		if cell == START_CELL or cell == boss_cell or cell == shop_cell:
			continue
		var required: Array = openings[cell]
		if not required.has(EAST) and not required.has(WEST):
			vertical_slots.append(cell)
		if not required.has(NORTH) and not required.has(SOUTH):
			horizontal_slots.append(cell)
	_shuffle(vertical_slots)
	_shuffle(horizontal_slots)
	room_scenes[shop_cell] = SHOP_SCENE
	for index in COPIES_PER_ROOM:
		room_scenes[vertical_slots[index]] = SPIKE_SCENE
		room_scenes[horizontal_slots[index]] = THIN_SCENE

	var remaining_cells: Array[Vector2i] = []
	for cell in main_path:
		if cell != START_CELL and cell != main_path.back() and not room_scenes.has(cell):
			remaining_cells.append(cell)
	for cell in branch_cells:
		if not room_scenes.has(cell):
			remaining_cells.append(cell)
	var general_scenes: Array[PackedScene] = []
	for scene in [BIG_SCENE, PITS_AND_SPIKES_SCENE, PITS_SCENE,
			SHOOTING_SCENE, WALLS_AND_SPIKES_SCENE, WALLS_SCENE]:
		for copy in COPIES_PER_ROOM:
			general_scenes.append(scene)
	assert(remaining_cells.size() == general_scenes.size())
	_shuffle(remaining_cells)
	_shuffle(general_scenes)
	for index in remaining_cells.size():
		room_scenes[remaining_cells[index]] = general_scenes[index]


func _room_origin(cell: Vector2i) -> Vector2i:
	if cell == boss_cell:
		return Vector2i(cell.x * CELL_WIDTH, boss_origin_y)
	return Vector2i(cell.x * CELL_WIDTH, cell.y * CELL_HEIGHT)


func _create_room(cell: Vector2i) -> void:
	var scene: PackedScene
	if cell == START_CELL:
		scene = START_SCENE
	elif cell == main_path.back():
		scene = BOSS_SCENE
	else:
		scene = room_scenes[cell]
	var room := scene.instantiate() as Node2D
	if cell == START_CELL:
		room.name = "Start"
	elif cell == main_path.back():
		room.name = "Boss"
	elif cell == shop_cell:
		room.name = "Shop"
	else:
		room.name = scene.resource_path.get_file().get_basename() + "_%d_%d" % [cell.x, cell.y]
	if cell == boss_cell:
		# Place the oversized boss room above every room in the entrance row.
		var nearest_top := 2147483647
		for other_cell in rooms:
			if other_cell.y == boss_entrance_cell.y:
				nearest_top = mini(nearest_top, _room_origin(other_cell).y + _bounds(rooms[other_cell]).position.y)
		assert(nearest_top != 2147483647)
		boss_origin_y = nearest_top - _bounds(room).end.y - BOSS_HALL_GAP
	room.position = Vector2(_room_origin(cell) * TILE_SIZE)
	$Rooms.add_child(room)
	_reserve_room_tiles(room, _room_origin(cell))
	rooms[cell] = room


func _bounds(room: Node2D) -> Rect2i:
	return (room.get_node("Floors") as TileMapLayer).get_used_rect()


func _place(scene: PackedScene, tile_position: Vector2i, parent: Node) -> void:
	var piece := scene.instantiate() as Node2D
	piece.position = Vector2(tile_position * TILE_SIZE)
	parent.add_child(piece)
	var piece_tiles: Dictionary = {}
	for child in piece.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			for local_tile in layer.get_used_cells():
				var world_tile := tile_position + local_tile
				if occupied_tiles.has(world_tile):
					layer.erase_cell(local_tile)
				else:
					piece_tiles[world_tile] = true
	for world_tile in piece_tiles:
		occupied_tiles[world_tile] = true


func _reserve_room_tiles(room: Node2D, tile_position: Vector2i) -> void:
	var room_tiles: Dictionary = {}
	for child in room.get_children():
		if child is TileMapLayer:
			for local_tile in (child as TileMapLayer).get_used_cells():
				var world_tile := tile_position + local_tile
				assert(not occupied_tiles.has(world_tile), "Generated rooms overlap at %s" % world_tile)
				room_tiles[world_tile] = true
	for world_tile in room_tiles:
		occupied_tiles[world_tile] = true


func _connect(a: Vector2i, b: Vector2i) -> void:
	if a.x == b.x:
		_connect_vertical(a if a.y < b.y else b, b if a.y < b.y else a)
	else:
		_connect_horizontal(a if a.x < b.x else b, b if a.x < b.x else a)


func _connect_horizontal(left: Vector2i, right: Vector2i) -> void:
	var left_room: Node2D = rooms[left]
	var right_room: Node2D = rooms[right]
	var left_bounds := _bounds(left_room)
	var right_bounds := _bounds(right_room)
	var left_origin := _room_origin(left)
	var right_origin := _room_origin(right)
	var left_edge := left_origin.x + left_bounds.end.x - 1
	var right_edge := right_origin.x + right_bounds.position.x
	_fill_horizontal(left_edge + 1, right_edge - 1, left_origin.y)


func _connect_vertical(top: Vector2i, bottom: Vector2i) -> void:
	var top_room: Node2D = rooms[top]
	var bottom_room: Node2D = rooms[bottom]
	var top_bounds := _bounds(top_room)
	var bottom_bounds := _bounds(bottom_room)
	var top_origin := _room_origin(top)
	var bottom_origin := _room_origin(bottom)
	var top_edge := top_origin.y + top_bounds.end.y - 1
	var bottom_edge := bottom_origin.y + bottom_bounds.position.y
	_fill_vertical(top_edge + 1, bottom_edge - 1, top_origin.x)


func _fill_horizontal(first_x: int, last_x: int, y: int) -> void:
	# Horizontal halls cover eight tiles, from local x=-4 through x=3.
	var x := first_x
	while x < last_x - 7:
		_place(HALL_HORIZONTAL, Vector2i(x + 4, y), $Connectors)
		x += 8
	_place(HALL_HORIZONTAL, Vector2i(last_x - 3, y), $Connectors)


func _fill_vertical(first_y: int, last_y: int, x: int) -> void:
	# Vertical halls cover six tiles, from local y=-3 through y=2.
	var y := first_y
	while y < last_y - 5:
		_place(HALL_VERTICAL, Vector2i(x, y + 3), $Connectors)
		y += 6
	_place(HALL_VERTICAL, Vector2i(x, last_y - 2), $Connectors)


func _cap_unused_openings(cell: Vector2i) -> void:
	var room: Node2D = rooms[cell]
	var bounds := _bounds(room)
	var origin := _room_origin(cell)
	var connected: Array = openings[cell]
	var available: Array[Vector2i] = [NORTH, SOUTH, WEST, EAST]
	if cell == boss_cell:
		available = [SOUTH]
	elif room.scene_file_path == SPIKE_SCENE.resource_path:
		available = [NORTH, SOUTH]
	elif room.scene_file_path == THIN_SCENE.resource_path:
		available = [WEST, EAST]
	for direction in available:
		if connected.has(direction):
			continue
		if direction == NORTH:
			_place(BLOCK_UP, origin + Vector2i(0, bounds.position.y - 1), $Blockades)
		elif direction == SOUTH:
			_place(BLOCK_DOWN, origin + Vector2i(0, bounds.end.y + 1), $Blockades)
		elif direction == WEST:
			_place(BLOCK_RIGHT, origin + Vector2i(bounds.position.x - 1, 0), $Blockades)
		else:
			_place(BLOCK_LEFT, origin + Vector2i(bounds.end.x + 1, 0), $Blockades)


func _setup_encounters() -> void:
	for cell in rooms:
		if cell == shop_cell:
			continue
		var encounter := Node2D.new()
		encounter.set_script(ENCOUNTER_SCRIPT)
		encounter.name = "Encounter"
		rooms[cell].add_child(encounter)
		var counts: Array[int] = [2, 3]
		if cell == START_CELL:
			counts = [1, 2]
		elif cell == boss_cell:
			counts = [3, 1]
			encounter.boss_room = true
		encounter.configure(rooms[cell], player, openings[cell], $CombatHUD, counts)
