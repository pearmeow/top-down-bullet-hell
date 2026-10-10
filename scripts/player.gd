extends CharacterBody2D

@export var move_speed: float = 90.0
@export var roll_speed: float = 210.0
@export var roll_duration: float = 0.28
@export var roll_cooldown: float = 0.55
@export var shot_interval: float = 0.4

signal health_changed(current: int, maximum: int)
signal died
signal coins_changed(value: int)
var coins := 0
var weapon_upgraded := false
var menu_open := false
var last_safe_position := Vector2.ZERO
var fall_time := 0.0
@export var max_health: int = 3
var health: int = 3
var invulnerability: float = 0.0
var dead := false

const BULLET_SCENE := preload("res://scenes/projectiles/bullet.tscn")
var facing := "down"
var roll_direction := Vector2.DOWN
var roll_time: float = 0.0
var cooldown: float = 0.0
var shot_time: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon: Node2D = $WeaponPivot
@onready var gun: Sprite2D = $WeaponPivot/Gun
@onready var muzzle: Marker2D = $WeaponPivot/Muzzle

func _ready() -> void:
	health = max_health

func take_damage(amount: int) -> void:
	if dead or invulnerability > 0.0 or roll_time > 0.0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	invulnerability = 1.0
	health_changed.emit(health, max_health)
	if health == 0:
		dead = true
		velocity = Vector2.ZERO
		weapon.hide()
		sprite.show()
		sprite.stop()
		sprite.modulate = Color(0.5, 0.5, 0.5)
		died.emit()

func _physics_process(delta: float) -> void:
	if dead:
		return
	if fall_time > 0.0:
		fall_time = maxf(0.0, fall_time - delta)
		sprite.scale = Vector2.ONE * (fall_time / 0.35)
		weapon.hide()
		if fall_time <= 0.0:
			global_position = last_safe_position
			reset_physics_interpolation()
			sprite.scale = Vector2.ONE
			weapon.show()
		return
	if menu_open:
		velocity = Vector2.ZERO
		sprite.play("idle_" + facing)
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	sprite.modulate = Color(1.0, 0.4, 0.4) if invulnerability > 0.85 else Color.WHITE
	sprite.visible = invulnerability <= 0.0 or int(invulnerability * 12.0) % 2 == 0
	cooldown = maxf(0.0, cooldown - delta)
	shot_time = maxf(0.0, shot_time - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO and roll_time <= 0.0:
		if absf(direction.x) >= absf(direction.y):
			facing = "left" if direction.x < 0.0 else "right"
		else:
			facing = "up" if direction.y < 0.0 else "down"
		sprite.flip_h = facing == "left"
		roll_direction = direction
	if Input.is_action_just_pressed("dodge") and cooldown <= 0.0 and roll_time <= 0.0:
		roll_time = roll_duration
		cooldown = roll_duration + roll_cooldown
		sprite.play("roll")
		sprite.speed_scale = 7.0 / (25.0 * roll_duration)
	if roll_time > 0.0:
		velocity = roll_direction * roll_speed
		roll_time = maxf(0.0, roll_time - delta)
	else:
		sprite.speed_scale = 1.0
		velocity = direction * move_speed
		if direction == Vector2.ZERO:
			sprite.play("idle_" + facing)
		else:
			sprite.play("walk_" + facing)
	move_and_slide()
	weapon.look_at(get_global_mouse_position())
	gun.flip_v = cos(weapon.global_rotation) < 0.0
	weapon.visible = roll_time <= 0.0
	gun.position.x = 5.0 if shot_time > shot_interval - 0.08 else 6.0
	muzzle.position.x = gun.position.x + gun.region_rect.size.x * gun.scale.x / 2.0
	if Input.is_action_pressed("shoot") and shot_time <= 0.0 and roll_time <= 0.0:
		_shoot()

func _shoot() -> void:
	if dead:
		return
	shot_time = shot_interval
	var shot_direction := Vector2.RIGHT.rotated(weapon.global_rotation)
	# Check the barrel segment so a gun cannot spawn a shot beyond a nearby wall.
	var query := PhysicsRayQueryParameters2D.create(global_position, muzzle.global_position, 1)
	query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return
	var bullet := BULLET_SCENE.instantiate() as CharacterBody2D
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.rotation = shot_direction.angle()
	bullet.velocity = shot_direction * bullet.speed
	bullet.damage = 2 if weapon_upgraded else 1

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)

func heal(amount: int) -> bool:
	if dead or health >= max_health:
		return false
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)
	return true

func upgrade_weapon() -> void:
	weapon_upgraded = true
	shot_interval = 0.3
	gun.modulate = Color(1.0, 0.85, 0.55)

func fall_into_pit() -> void:
	if dead or roll_time > 0.0 or fall_time > 0.0:
		return
	take_damage(1)
	if not dead:
		fall_time = 0.35
		velocity = Vector2.ZERO
