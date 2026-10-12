extends Node2D

var radius := 3.0

func _ready() -> void:
	var collider := get_parent().get_node("CollisionShape2D") as CollisionShape2D
	radius = (collider.shape as CircleShape2D).radius
	queue_redraw()

func _draw() -> void:
	# The visible outer edge is the collision circle, with no rotating decoration.
	draw_circle(Vector2.ZERO, radius, Color("e43b44"))
	draw_circle(Vector2.ZERO, maxf(0.0, radius - 1.0), Color("fff5ed"))
