extends Node2D

var age := 0.0

func _ready() -> void:
	add_to_group("spawn_markers")
	z_index = 6

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(age * 18.0) * 0.12
	draw_circle(Vector2.ZERO, 8.0 * pulse, Color(0.85, 0.08, 0.1, 0.45))
	draw_arc(Vector2.ZERO, 11.0 * pulse, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, 0.9), 1.0)
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.5, 0.35))
