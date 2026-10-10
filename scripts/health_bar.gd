extends Control

var current: int = 3
var maximum: int = 3
var hit_flash: float = 0.0

func set_health(value: int, total: int) -> void:
	if value < current:
		hit_flash = 0.22
	current = value
	maximum = total
	queue_redraw()

func _process(delta: float) -> void:
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()

func _draw() -> void:
	var brass := Color("94774d")
	var iron := Color("302b29")
	var dark := Color("110f12")
	draw_rect(Rect2(2, 3, 174, 30), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(0, 0, 174, 30), dark)
	draw_rect(Rect2(2, 2, 170, 26), brass)
	draw_rect(Rect2(4, 4, 166, 22), iron)
	# Small cross-shaped crest and rivets echo the knight's armor.
	draw_rect(Rect2(12, 8, 4, 14), brass)
	draw_rect(Rect2(8, 12, 12, 4), brass)
	for corner in [Vector2(4, 4), Vector2(167, 4), Vector2(4, 23), Vector2(167, 23)]:
		draw_rect(Rect2(corner, Vector2(3, 3)), Color("cfb58a"))
	var segment_width := 138.0 / maxi(1, maximum)
	for index in maximum:
		var rect := Rect2(26 + index * segment_width, 8, segment_width - 3, 14)
		draw_rect(rect, Color("191416"))
		if index < current:
			draw_rect(rect, Color("bd6659") if hit_flash > 0.0 else Color("87342e"))
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color("b94b3e"))
			draw_rect(Rect2(rect.position + Vector2(0, 11), Vector2(rect.size.x, 3)), Color("542323"))
