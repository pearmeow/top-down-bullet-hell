extends CharacterBody2D

var lifetime := 3.0
var spin := 9.0

func _physics_process(delta: float) -> void:
	lifetime -= delta
	$Sprite2D.rotation += spin * delta
	if lifetime <= 0.0:
		queue_free()
		return
	var hit := move_and_collide(velocity * delta)
	if hit:
		var target := hit.get_collider()
		if target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(1)
		queue_free()
