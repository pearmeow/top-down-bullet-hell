extends Node2D

const BULLET := preload("res://scenes/projectiles/bullet.tscn")
var player: CharacterBody2D
var shot_time := 0.0
var age := 0.0

func _ready() -> void:
	add_to_group("familiars")
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/Character/Props/Individual_Props/skull_01.png")
	sprite.modulate = Color(0.65, 0.9, 1.0)
	sprite.position.y = -8.0
	add_child(sprite)
	z_index = 15

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.dead:
		return
	age += delta
	get_child(0).position.y = -8.0 + sin(age * 3.0) * 2.0
	var destination := player.global_position + Vector2(-20, 12)
	if global_position.distance_to(player.global_position) > 160.0:
		global_position = player.global_position
	else:
		var query := PhysicsRayQueryParameters2D.create(global_position, destination, 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			destination = player.global_position
			query.to = destination
			if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				destination = global_position
				for encounter in get_tree().get_nodes_in_group("encounters"):
					var path: PackedVector2Array = encounter.path_between(global_position, player.global_position)
					while not path.is_empty() and global_position.distance_to(path[0]) < 4.0:
						path.remove_at(0)
					if not path.is_empty():
						destination = path[0]
						break
		var next_position := global_position.move_toward(destination, 105.0 * delta)
		query.from = global_position
		query.to = next_position
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			global_position = next_position
	shot_time -= delta
	if shot_time > 0.0 or player.menu_open:
		return
	var target: CharacterBody2D
	var distance := 180.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead or enemy.grace > 0.0:
			continue
		var candidate: float = global_position.distance_to(enemy.global_position)
		var query := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, 1)
		if candidate < distance and get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			target = enemy
			distance = candidate
	if target == null:
		return
	shot_time = 0.85
	var bullet := BULLET.instantiate() as CharacterBody2D
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	var direction := global_position.direction_to(target.global_position)
	bullet.rotation = direction.angle()
	bullet.velocity = direction * bullet.speed
	bullet.modulate = Color(0.5, 0.85, 1.0)
