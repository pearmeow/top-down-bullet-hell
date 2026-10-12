extends Node

## Tracks the current run for the end screen: time, kills, coins earned, rooms cleared,
## hits taken, and where the run ended.

var level: Node2D
var player: CharacterBody2D
var time := 0.0
var kills := 0
var coins_earned := 0
var hits_taken := 0
var ended_in := ""
var finished := false

func configure(value: Node2D) -> void:
	level = value
	player = level.player
	var coins := [player.coins]
	player.coins_changed.connect(func(amount: int) -> void:
		if amount > coins[0]:
			coins_earned += amount - coins[0]
		coins[0] = amount)
	var health := [player.health]
	player.health_changed.connect(func(current: int, _maximum: int) -> void:
		if current < health[0]:
			hits_taken += 1
		health[0] = current)
	player.died.connect(_player_died)
	get_tree().node_added.connect(_node_added)

func _node_added(node: Node) -> void:
	if node.is_in_group("enemies") and node.has_signal("died"):
		node.died.connect(func() -> void: kills += 1)

func _process(delta: float) -> void:
	if finished or player.dead:
		return
	time += delta

func _player_died() -> void:
	finished = true
	for cell in level.rooms:
		var room: Node2D = level.rooms[cell]
		var encounter := room.get_node_or_null("Encounter")
		if cell == level.boss_cell and encounter != null and encounter.active:
			ended_in = "Slain by The Maw"
			return
		var floors := room.get_node("Floors") as TileMapLayer
		if floors.get_cell_source_id(floors.local_to_map(floors.to_local(player.global_position))) != -1:
			ended_in = "Fell in %s" % _room_label(room, cell)
			return
	ended_in = "Fell in the halls"

func _room_label(room: Node2D, cell: Vector2i) -> String:
	if cell == level.START_CELL:
		return "the entrance"
	if cell == level.shop_cell:
		return "the shop"
	var base := room.scene_file_path.get_file().get_basename().replace("_room", "").replace("_", " ")
	return "the %s room" % base

func summary() -> String:
	# The HUD's death handler can run before ours, so work out the cause on demand.
	if player.dead and ended_in.is_empty():
		_player_died()
	var rooms_cleared := 0
	for encounter in get_tree().get_nodes_in_group("encounters"):
		if encounter.cleared:
			rooms_cleared += 1
	var lines := [
		"Time  %d:%02d" % [int(time) / 60, int(time) % 60],
		"Enemies slain  %d" % kills,
		"Rooms cleared  %d / %d" % [rooms_cleared, get_tree().get_nodes_in_group("encounters").size()],
		"Coins earned  %d" % coins_earned,
		"Hits taken  %d" % hits_taken,
	]
	if not ended_in.is_empty():
		lines.push_front(ended_in)
	return "\n".join(lines)
