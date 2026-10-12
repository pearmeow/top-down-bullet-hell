extends Control

var amount := 0
var flash := 0.0
var font: Font
const ICON := preload("res://assets/Character/Props/Individual_Props/gold_stack_01.png")

func set_coins(value: int) -> void:
	if value > amount:
		flash = 0.2
	amount = value
	queue_redraw()

func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(2, 3, 100, 30), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(0, 0, 100, 30), Color("110f12"))
	draw_rect(Rect2(2, 2, 96, 26), Color("e5cb85") if flash > 0.0 else Color("94774d"))
	draw_rect(Rect2(4, 4, 92, 22), Color("302b29"))
	for corner in [Vector2(4, 4), Vector2(93, 4), Vector2(4, 23), Vector2(93, 23)]:
		draw_rect(Rect2(corner, Vector2(3, 3)), Color("cfb58a"))
	draw_texture_rect(ICON, Rect2(8, 3, 24, 24), false)
	if font != null:
		draw_string(font, Vector2(38, 24), str(amount), HORIZONTAL_ALIGNMENT_LEFT, 55, 22, Color("cfb58a"))
