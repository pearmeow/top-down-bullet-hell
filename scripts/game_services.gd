extends Node2D

const PICKUP := preload("res://scripts/pickup.gd")
const FAMILIAR := preload("res://scripts/familiar.gd")
var level: Node2D
var player: CharacterBody2D
var merchant: Sprite2D
var shop_open := false
var has_familiar := false
var clears := 0

func configure(value: Node2D) -> void:
	level = value
	player = level.player
	merchant = Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/Enemies/dungeon_characters.png")
	atlas.region = Rect2(128, 144, 16, 32)
	merchant.texture = atlas
	merchant.name = "Shopkeeper"
	merchant.z_index = 10
	add_child(merchant)
	merchant.global_position = safe_position(level.rooms[level.shop_cell], level.rooms[level.shop_cell].global_position + Vector2(8, -24)) + Vector2(0, -8)
	player.last_safe_position = player.global_position
	level.get_node("CombatHUD").bind_services(self)

func safe_position(room: Node2D, point: Vector2) -> Vector2:
	var floors := room.get_node("Floors") as TileMapLayer
	var best := point
	var distance := INF
	for cell in floors.get_used_cells():
		var safe := true
		for name in ["Walls", "Structures", "Pits", "Spikes"]:
			var layer := room.get_node(name) as TileMapLayer
			if layer.get_cell_source_id(cell) != -1:
				safe = false
		var candidate := floors.to_global(floors.map_to_local(cell))
		if safe and candidate.distance_squared_to(point) < distance:
			best = candidate
			distance = candidate.distance_squared_to(point)
	return best

func drop(kind: String, point: Vector2, amount: int = 1) -> Node2D:
	var pickup := Node2D.new()
	pickup.set_script(PICKUP)
	pickup.kind = kind
	pickup.amount = amount
	pickup.player = player
	add_child(pickup)
	pickup.global_position = point
	return pickup

func enemy_reward(enemy: CharacterBody2D) -> void:
	var point := enemy.global_position
	if is_instance_valid(enemy.encounter):
		point = safe_position(enemy.encounter.room, point)
	drop("coin", point, 2 if enemy.ranged else 1)

func room_reward(room: Node2D) -> void:
	clears += 1
	var point := safe_position(room, player.global_position + Vector2(24, 0))
	drop("coin", point, 3)
	if clears % 3 == 0:
		drop("health", safe_position(room, point + Vector2(24, 0)))
	if clears == 4 and not player.weapon_upgraded:
		drop("weapon", safe_position(room, point + Vector2(-24, 0)))

func _physics_process(_delta: float) -> void:
	if player == null or player.dead:
		if shop_open:
			close_shop()
		return
	var near := player.global_position.distance_to(merchant.global_position + Vector2(0, 8)) < 44.0
	var hud := level.get_node("CombatHUD")
	hud.set_interaction("E · Speak to the shopkeeper" if near and not shop_open else "")
	if shop_open and (not near or Input.is_action_just_pressed("cancel_shop")):
		close_shop()
	elif near and Input.is_action_just_pressed("interact"):
		if shop_open:
			close_shop()
		else:
			shop_open = true
			player.menu_open = true
			hud.open_shop()
	_check_hazards()

func _check_hazards() -> void:
	if player.fall_time > 0.0:
		return
	var hazard := ""
	var on_floor := false
	for room in level.rooms.values():
		var floors := room.get_node("Floors") as TileMapLayer
		var cell := floors.local_to_map(floors.to_local(player.global_position))
		if (room.get_node("Pits") as TileMapLayer).get_cell_source_id(cell) != -1:
			hazard = "pit"
		elif (room.get_node("Spikes") as TileMapLayer).get_cell_source_id(cell) != -1:
			hazard = "spike"
		elif floors.get_cell_source_id(cell) != -1:
			on_floor = true
		else:
			continue
		break
	if hazard == "pit" and player.roll_time <= 0.0:
		player.fall_into_pit()
	elif hazard == "spike" and player.roll_time <= 0.0:
		player.take_damage(1)
	elif hazard.is_empty() and on_floor:
		player.last_safe_position = player.global_position

func close_shop() -> void:
	shop_open = false
	player.menu_open = false
	level.get_node("CombatHUD").close_shop()

func buy(item: String) -> String:
	if not shop_open or player.dead:
		return "Speak to the shopkeeper first."
	var prices := {"heal": 4, "weapon": 8, "familiar": 10}
	if not prices.has(item):
		return ""
	if item == "heal" and player.health == player.max_health:
		return "You're already at full health."
	if item == "weapon" and player.weapon_upgraded:
		return "Your flintlock is already upgraded."
	if item == "familiar" and has_familiar:
		return "Your familiar is already with you."
	var price: int = prices[item]
	if player.coins < price:
		return "You need %d more coins." % (price - player.coins)
	player.add_coins(-price)
	if item == "heal":
		player.heal(1)
	elif item == "weapon":
		player.upgrade_weapon()
	else:
		has_familiar = true
		var familiar := Node2D.new()
		familiar.set_script(FAMILIAR)
		familiar.player = player
		add_child(familiar)
		familiar.global_position = player.global_position
	return "A deal well made."
