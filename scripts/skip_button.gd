extends Button

## Testing shortcut: teleports the player to the boss room (and spawns the boss right away)
## or to the shopkeeper.

var level: Node2D
var target := "boss"

func configure(value: Node2D, destination: String, row: int) -> void:
	level = value
	target = destination
	text = "Skip to boss" if target == "boss" else "Skip to shop"
	theme = level.get_node("CombatHUD").ui_theme
	# No focus, so Space (dodge) can't press it again by accident.
	focus_mode = Control.FOCUS_NONE
	# Bottom-right, clear of the minimap.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -170.0
	offset_right = -16.0
	offset_bottom = -16.0 - row * 44.0
	offset_top = offset_bottom - 36.0
	pressed.connect(_skip)

func _process(_delta: float) -> void:
	var player: CharacterBody2D = level.player
	# Usable mid-fight (the start room's fight begins on spawn), but not once the boss is engaged.
	var encounter := _boss_encounter()
	var locked: bool = encounter == null or encounter.active or (target == "boss" and encounter.cleared)
	visible = not locked and not player.dead and not player.menu_open

func _boss_encounter() -> Node2D:
	return level.rooms[level.boss_cell].get_node_or_null("Encounter") as Node2D

func _skip() -> void:
	var services: Node2D = level.services
	if services.shop_open:
		services.close_shop()
	if target == "shop":
		_teleport(level.rooms[level.shop_cell], services.merchant.global_position + Vector2(0, 32))
		return
	var encounter := _boss_encounter()
	if encounter == null or encounter.active or encounter.cleared:
		return
	# Drop the warm-up wave so the boss is the only wave.
	var boss_only: Array[int] = [1]
	encounter.waves = boss_only
	var room: Node2D = level.rooms[level.boss_cell]
	var floors := room.get_node("Floors") as TileMapLayer
	var bounds := floors.get_used_rect()
	_teleport(room, floors.to_global(Vector2(bounds.get_center().x, bounds.end.y - 5) * 16.0))

func _teleport(room: Node2D, point: Vector2) -> void:
	var player: CharacterBody2D = level.player
	player.global_position = level.services.safe_position(room, point)
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	player.last_safe_position = player.global_position
