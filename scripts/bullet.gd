extends CharacterBody2D

@export var speed: float = 320.0
@export var damage: int = 1
@export var lifetime: float = 1.6

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var hit := move_and_collide(velocity * delta)
	if hit:
		var target := hit.get_collider()
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
