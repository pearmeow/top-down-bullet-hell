extends Control

## Top-center boss bar, styled like health_bar.gd, with notches for phased bosses.

const WIDTH := 360.0
var boss: CharacterBody2D
var font: Font
var display_name := ""
var phase_count := 1
var current_phase := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, 44)

func _process(_delta: float) -> void:
	position = Vector2((get_viewport_rect().size.x - WIDTH) / 2.0, 16)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(boss):
		return
	var brass := Color("94774d")
	var dark := Color("110f12")
	if font != null:
		var title := display_name
		if phase_count > 1:
			title += "  ·  Phase %d" % current_phase
		draw_string(font, Vector2(0, 14), title, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 16, Color("cfb58a"))
	draw_rect(Rect2(0, 20, WIDTH, 20), dark)
	draw_rect(Rect2(2, 22, WIDTH - 4, 16), brass)
	draw_rect(Rect2(4, 24, WIDTH - 8, 12), Color("191416"))
	var fraction := float(boss.health) / float(maxi(1, boss.max_health))
	draw_rect(Rect2(4, 24, (WIDTH - 8) * fraction, 12), Color("87342e"))
	draw_rect(Rect2(4, 24, (WIDTH - 8) * fraction, 3), Color("b94b3e"))
	for index in range(1, phase_count):
		var threshold := float(index) / float(phase_count)
		draw_rect(Rect2(4 + (WIDTH - 8) * threshold - 1, 22, 2, 16), brass)
