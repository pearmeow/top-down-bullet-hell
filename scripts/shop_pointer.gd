extends Node2D

## A small brass arrow that orbits the player and points (as the crow flies) at the shopkeeper.
## It disappears for good once the player has found the shop.

const RADIUS := 22.0
var player: CharacterBody2D
var merchant: Node2D
var age := 0.0

func _ready() -> void:
	z_index = 30

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(merchant):
		return
	if player.global_position.distance_to(merchant.global_position) < 64.0:
		queue_free()
		return
	age += delta
	var direction := player.global_position.direction_to(merchant.global_position)
	global_position = player.global_position + Vector2(0, -6) + direction * (RADIUS + sin(age * 4.0) * 2.0)
	rotation = direction.angle()
	visible = not player.dead and not player.menu_open
	queue_redraw()

func _draw() -> void:
	var tip := PackedVector2Array([Vector2(6, 0), Vector2(-4, -5), Vector2(-2, 0), Vector2(-4, 5)])
	var outline := PackedVector2Array([Vector2(8, 0), Vector2(-5, -7), Vector2(-3, 0), Vector2(-5, 7)])
	draw_colored_polygon(outline, Color("110f12"))
	draw_colored_polygon(tip, Color("cfb58a"))
