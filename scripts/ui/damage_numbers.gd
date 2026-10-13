extends Node2D

## Floating damage numbers over enemies. Watches every node in the "enemies" group for health
## drops, so enemy scripts don't need to report hits.

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")
const LIFETIME := 0.7

var tracked: Dictionary = {}
var numbers: Array[Dictionary] = []

func _ready() -> void:
	z_index = 40
	get_tree().node_added.connect(_node_added)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_node_added(enemy)

func _node_added(node: Node) -> void:
	if node.is_in_group("enemies") and "health" in node and not tracked.has(node):
		tracked[node] = -1
		node.tree_exiting.connect(_check.bind(node))

func _physics_process(delta: float) -> void:
	for enemy in tracked.keys():
		if is_instance_valid(enemy):
			_check(enemy)
		else:
			tracked.erase(enemy)
	for number in numbers:
		number.age += delta
	numbers = numbers.filter(func(number: Dictionary) -> bool: return number.age < LIFETIME)
	queue_redraw()

func _check(enemy: Node) -> void:
	if not tracked.has(enemy):
		return
	var health: int = enemy.health
	var previous: int = tracked[enemy]
	if previous >= 0 and health < previous:
		var top := -44.0 if enemy.get("boss") == true else -20.0
		numbers.append({"value": previous - health, "position": enemy.global_position + Vector2(randf_range(-5, 5), top), "age": 0.0, "kill": health == 0})
	tracked[enemy] = health
	if health == 0 or enemy.is_queued_for_deletion():
		tracked.erase(enemy)

func _draw() -> void:
	for number in numbers:
		var t: float = number.age / LIFETIME
		var point: Vector2 = to_local(number.position) + Vector2(0, -14.0 * t)
		var color := Color("ffd27a") if number.kill else Color("f1dcb0")
		color.a = 1.0 - t * t
		var text := str(number.value)
		draw_string(UI_STYLE.FONT, point + Vector2(-8, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 16, 10, Color(0, 0, 0, color.a))
		draw_string(UI_STYLE.FONT, point + Vector2(-8, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 16, 10, color)
