extends Control

## Top-right map of the generated floor. Rooms appear once visited; rooms one door away show
## as outlines. Tab toggles a large centered view.

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")
const CELL := Vector2(18, 13)
const GAP := Vector2(7, 7)
const PADDING := 10.0

var level: Node2D
var visited: Dictionary = {}
var room_rects: Dictionary = {}
var current := Vector2i(-1, -1)
var expanded := false
var age := 0.0

func configure(value: Node2D) -> void:
	level = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cell in level.rooms:
		var floors := (level.rooms[cell] as Node2D).get_node("Floors") as TileMapLayer
		var used := floors.get_used_rect()
		room_rects[cell] = Rect2(floors.to_global(Vector2(used.position) * 16.0), Vector2(used.size) * 16.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		expanded = not expanded
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if level == null or not is_instance_valid(level.player):
		return
	age += delta
	var point: Vector2 = level.player.global_position
	for cell in room_rects:
		if (room_rects[cell] as Rect2).has_point(point):
			current = cell
			visited[cell] = true
	var scale_factor := 2.0 if expanded else 1.0
	size = _map_size() * scale_factor
	var screen := get_viewport_rect().size
	position = (screen - size) / 2.0 if expanded else Vector2(screen.x - size.x - 16.0, 16.0)
	queue_redraw()

func _map_size() -> Vector2:
	return Vector2(level.GRID_WIDTH, level.GRID_HEIGHT) * (CELL + GAP) - GAP + Vector2.ONE * PADDING * 2.0

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2.ONE * PADDING + Vector2(cell) * (CELL + GAP), CELL)

func _known(cell: Vector2i) -> bool:
	if visited.has(cell):
		return true
	for edge in level.edges:
		if (edge.a == cell and visited.has(edge.b)) or (edge.b == cell and visited.has(edge.a)):
			return true
	return false

func _draw() -> void:
	if level == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (2.0 if expanded else 1.0))
	var area := Rect2(Vector2.ZERO, _map_size())
	draw_rect(area, Color(0.04, 0.03, 0.05, 0.92 if expanded else 0.72))
	draw_rect(area, UI_STYLE.BRASS, false, 2.0)
	for edge in level.edges:
		if not (visited.has(edge.a) or visited.has(edge.b)):
			continue
		draw_line(_cell_rect(edge.a).get_center(), _cell_rect(edge.b).get_center(), Color("5b4d3a"), 3.0)
	for cell in level.rooms:
		if not _known(cell):
			continue
		var rect := _cell_rect(cell)
		if visited.has(cell):
			var fill := UI_STYLE.IRON.lightened(0.15)
			var encounter := (level.rooms[cell] as Node2D).get_node_or_null("Encounter")
			if encounter != null and not encounter.cleared:
				fill = Color("4a2a28")
			if cell == current:
				fill = UI_STYLE.BRASS.lerp(UI_STYLE.HIGHLIGHT, 0.5 + 0.5 * sin(age * 5.0))
			draw_rect(rect, fill)
			draw_rect(rect, UI_STYLE.PARCHMENT, false, 1.0)
		else:
			draw_rect(rect, Color(0, 0, 0, 0.5))
			draw_rect(rect, Color("6b5f50"), false, 1.0)
		_draw_icon(cell, rect.get_center(), UI_STYLE.INK if cell == current else UI_STYLE.PARCHMENT)
	draw_set_transform(Vector2.ZERO)
	if expanded:
		var font := UI_STYLE.FONT
		draw_string(font, Vector2(0, size.y + 22), "Tab · close map", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, UI_STYLE.PARCHMENT)

func _draw_icon(cell: Vector2i, center: Vector2, start_color: Color) -> void:
	if cell == level.boss_cell:
		draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), Color("b94b3e"))
		draw_rect(Rect2(center - Vector2(2, 1), Vector2(4, 2)), UI_STYLE.INK)
	elif cell == level.shop_cell:
		draw_circle(center, 3.5, Color("e8c35a"))
		draw_circle(center, 1.5, Color("8a6a1f"))
	elif cell == level.START_CELL:
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 3), center + Vector2(-4, 3)]), start_color)
