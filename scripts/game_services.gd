extends Node2D

const PICKUP := preload("res://scripts/pickup.gd")
const FAMILIAR := preload("res://scripts/familiar.gd")
var level: Node2D
var player: CharacterBody2D
var guide: Sprite2D
var tutorial_open := false
var merchant: Sprite2D
var shop_open := false
var has_familiar := false
var clears := 0
var pit_exposure := 0.0
const PIT_RESPAWN_BUFFER := 8.0
@export_range(0.0, 1.0) var room_health_reward_chance := 0.35

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
	guide = Sprite2D.new()
	var guide_atlas := AtlasTexture.new()
	guide_atlas.atlas = preload("res://assets/Enemies/dungeon_characters.png")
	guide_atlas.region = Rect2(128, 176, 16, 32)
	guide.texture = guide_atlas
	guide.name = "TutorialGuide"
	guide.z_index = 10
	add_child(guide)
	guide.global_position = safe_position(level.rooms[level.START_CELL], player.global_position + Vector2(48, 0)) + Vector2(0, -8)
	var name_label := Label.new()
	name_label.text = "Guide"
	name_label.add_theme_font_override("font", preload("res://assets/Fonts/PixelifySans.ttf"))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.modulate = Color(0.81, 0.71, 0.54)
	name_label.position = Vector2(-14, -26)
	name_label.scale = Vector2(0.5, 0.5)
	guide.add_child(name_label)
	_add_npc_collision(merchant)
	_add_npc_collision(guide)
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
		if room.is_structure_blocked(candidate, 6.0):
			safe = false
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
	var coin := drop("coin", point, 2 if enemy.ranged else 1)
	if is_instance_valid(enemy.encounter):
		coin.reward_room = enemy.encounter.room

func room_reward(room: Node2D) -> void:
	clears += 1
	var point := safe_position(room, player.global_position + Vector2(24, 0))
	var index := 0
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.kind == "coin" and pickup.reward_room == room and not pickup.is_queued_for_deletion():
			pickup.collect_automatically(minf(index * 0.04, 0.2))
			index += 1
	if level.rng.randf() < room_health_reward_chance:
		drop("health", point)
	else:
		for bonus in 3:
			var coin := drop("coin", point + Vector2((bonus - 1) * 8, -4))
			coin.reward_room = room
			coin.collect_automatically(0.08 * bonus)

func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		if shop_open:
			close_shop()
		if tutorial_open:
			close_tutorial()
		return
	var guide_near := player.global_position.distance_to(guide.global_position + Vector2(0, 8)) < 56.0
	var near := player.global_position.distance_to(merchant.global_position + Vector2(0, 8)) < 44.0
	var hud := level.get_node("CombatHUD")
	var prompt := ""
	if not shop_open and not tutorial_open:
		if guide_near:
			prompt = "E · Talk to the guide (optional)"
		elif near:
			prompt = "E · Speak to the shopkeeper"
	hud.set_interaction(prompt)
	if tutorial_open:
		if not guide_near or Input.is_action_just_pressed("cancel_shop") or Input.is_action_just_pressed("interact"):
			close_tutorial()
	elif guide_near and Input.is_action_just_pressed("interact"):
		tutorial_open = true
		player.menu_open = true
		hud.open_tutorial()
	elif shop_open and (not near or Input.is_action_just_pressed("cancel_shop")):
		close_shop()
	elif near and Input.is_action_just_pressed("interact"):
		if shop_open:
			close_shop()
		else:
			shop_open = true
			player.menu_open = true
			hud.open_shop()
	_check_hazards(delta)

func _check_hazards(delta: float = 1.0 / 60.0) -> void:
	if player.fall_time > 0.0:
		return
	var hazard := ""
	var on_floor := false
	var safe_from_pits := false
	var body_shape := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var body_radius := body_shape.radius
	for room in level.rooms.values():
		var floors := room.get_node("Floors") as TileMapLayer
		var pits := room.get_node("Pits") as TileMapLayer
		var spikes := room.get_node("Spikes") as TileMapLayer
		var cell := floors.local_to_map(floors.to_local(player.global_position))
		var pit_cell := pits.local_to_map(pits.to_local(player.global_position))
		if pits.get_cell_source_id(pit_cell) != -1:
			hazard = "pit" if _pit_area_matches(pits, player.global_position, body_radius, true) else "pit_edge"
		elif spikes.get_cell_source_id(cell) != -1:
			if spikes.get_cell_atlas_coords(cell) == Vector2i(4, 3):
				hazard = "spike"
		elif floors.get_cell_source_id(cell) != -1:
			on_floor = true
			safe_from_pits = _pit_area_matches(pits, player.global_position, body_radius + PIT_RESPAWN_BUFFER, false)
		else:
			continue
		break
	if hazard == "pit" and player.roll_time <= 0.0 and player.pit_landing_grace <= 0.0:
		pit_exposure += delta
		if pit_exposure >= 0.12:
			pit_exposure = 0.0
			player.fall_into_pit()
	else:
		pit_exposure = 0.0
	if hazard == "spike" and player.roll_time <= 0.0:
		player.take_damage(1)
	elif hazard.is_empty() and on_floor and safe_from_pits:
		player.last_safe_position = player.global_position

func _pit_area_matches(pits: TileMapLayer, world_position: Vector2, radius: float, expect_pit: bool) -> bool:
	var local_position := pits.to_local(world_position)
	var extent := Vector2.ONE * radius
	var first := pits.local_to_map(local_position - extent)
	var last := pits.local_to_map(local_position + extent)
	var half_tile := Vector2(pits.tile_set.tile_size) / 2.0
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var center := pits.map_to_local(cell)
			var nearest := Vector2(
				clampf(local_position.x, center.x - half_tile.x, center.x + half_tile.x),
				clampf(local_position.y, center.y - half_tile.y, center.y + half_tile.y)
			)
			if local_position.distance_squared_to(nearest) < radius * radius:
				if (pits.get_cell_source_id(cell) != -1) != expect_pit:
					return false
	return true

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

func close_tutorial() -> void:
	tutorial_open = false
	player.menu_open = false
	level.get_node("CombatHUD").close_tutorial()

func _add_npc_collision(npc: Sprite2D) -> void:
	var body := StaticBody2D.new()
	body.name = "Body"
	body.position = Vector2(0, 8)
	body.collision_layer = 32
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	body.add_child(shape)
	npc.add_child(body)
