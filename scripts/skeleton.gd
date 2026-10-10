extends CharacterBody2D

signal died
const PROJECTILE := preload("res://scenes/projectiles/enemy_projectile.tscn")
var attack_pace := 1.0
var projectile_pace := 1.0
var attack_timer := 1.0
var windup := 0.0
var aim := Vector2.RIGHT
@export var boss := false
var attack_cycle := 0
@export var ranged := false
@export var base_tint := Color.WHITE
@export var speed: float = 48.0
@export var max_health: int = 3
var health: int = 3
var player: CharacterBody2D
var grace: float = 0.8
var flash: float = 0.0
var dead := false
var encounter: Node2D
var path := PackedVector2Array()
var path_timer: float = 0.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	var level := get_tree().current_scene
	if level == null:
		level = get_parent()
	while level != null and not "playtest_mode" in level:
		level = level.get_parent()
	if level != null and level.playtest_mode:
		attack_pace = 2.0
		projectile_pace = 0.65
		speed *= 0.75
		max_health = 10 if boss else 2
	health = max_health
	attack_timer = randf_range(0.35, 0.85) * attack_pace
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	sprite.modulate = Color(2.5, 0.7, 0.7) if flash > 0.0 else base_tint
	grace = maxf(0.0, grace - delta)
	if dead or not is_instance_valid(player) or player.dead or grace > 0.0:
		velocity = Vector2.ZERO
		sprite.play("idle")
		return
	var query_to_player := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	var can_see := get_world_2d().direct_space_state.intersect_ray(query_to_player).is_empty()
	var destination := player.global_position
	var can_walk := can_see
	if is_instance_valid(encounter):
		can_walk = can_walk and encounter.can_walk_direct(global_position, destination)
	if is_instance_valid(encounter) and not can_walk:
		path_timer -= delta
		if path_timer <= 0.0:
			path = encounter.path_between(global_position, player.global_position)
			# The first point is our current tile center; don't walk back to it.
			if path.size() > 1:
				path.remove_at(0)
			path_timer = 0.25
		while not path.is_empty() and global_position.distance_to(path[0]) < 4.0:
			path.remove_at(0)
		destination = global_position if path.is_empty() else path[0]
	var direction := global_position.direction_to(destination)
	attack_timer -= delta
	if windup > 0.0:
		windup = maxf(0.0, windup - delta)
		sprite.modulate = Color(1.6, 1.1, 0.55)
		if windup <= 0.0:
			_throw()
			attack_timer = (randf_range(0.9, 1.3) if ranged else randf_range(0.55, 0.9)) * attack_pace
	elif attack_timer <= 0.0 and can_see and global_position.distance_to(player.global_position) < 260.0:
		windup = (0.4 if ranged else 0.3) * (1.4 if attack_pace > 1.0 else 1.0)
		aim = global_position.direction_to(player.global_position)
	var desired := direction * minf(speed, global_position.distance_to(destination) / delta)
	if ranged and can_see:
		var distance := global_position.distance_to(player.global_position)
		if distance >= 90.0 and distance <= 150.0:
			desired = Vector2.ZERO
		elif distance < 90.0:
			var retreat := -global_position.direction_to(player.global_position)
			var next_position := global_position + retreat * 16.0
			var safe := true
			if is_instance_valid(encounter):
				var cell: Vector2i = encounter.floors.local_to_map(encounter.floors.to_local(next_position))
				safe = encounter.safe_cells.has(cell)
			desired = retreat * speed if safe else Vector2.ZERO
	if windup > 0.0:
		desired = Vector2.ZERO
	velocity = velocity.move_toward(desired, 420.0 * delta)
	move_and_slide()
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0
	sprite.play("walk" if velocity.length() > 3.0 else "idle")
	if global_position.distance_to(player.global_position) <= 11.0:
		var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			player.take_damage(1)

func take_damage(amount: int) -> void:
	if dead or amount <= 0:
		return
	health = maxi(0, health - amount)
	flash = 0.12
	if health == 0:
		dead = true
		var services := get_tree().current_scene.get_node_or_null("GameServices")
		if services != null:
			services.enemy_reward(self)
		died.emit()
		queue_free()

func _throw() -> void:
	if dead or player.dead:
		return
	var angles := [-15.0, 0.0, 15.0] if ranged else [0.0]
	if boss:
		attack_cycle += 1
		angles = [-30.0, -15.0, 0.0, 15.0, 30.0]
		if attack_cycle % 2 == 0:
			angles = []
			for index in 12:
				angles.append(float(index) * 30.0)
	for angle in angles:
		var projectile := PROJECTILE.instantiate() as CharacterBody2D
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position
		projectile.velocity = aim.rotated(deg_to_rad(angle)) * (145.0 if ranged else 165.0) * projectile_pace
