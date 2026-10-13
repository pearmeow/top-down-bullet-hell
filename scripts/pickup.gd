extends Node2D

var kind := "coin"
var reward_room: Node2D
var amount := 1
var player: CharacterBody2D
var sprite: Sprite2D
var age := 0.0
var collecting := false
var flight_time := 0.0
var flight_delay := 0.0
var flight_start := Vector2.ZERO
var flight_control := Vector2.ZERO

func _ready() -> void:
	add_to_group("pickups")
	sprite = Sprite2D.new()
	var files := {"coin": "gold_stack_01", "health": "potion_red_01", "weapon": "key_01"}
	var file: String = files.get(kind, "gold_stack_01")
	var path := "res://assets/Character/Props/Individual_Props/%s.png" % file
	if not ResourceLoader.exists(path):
		path = "res://assets/Character/Props/Individual_Props/skull_01.png"
	sprite.texture = load(path)
	if kind == "health":
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/Enemies/dungeon_characters.png")
		atlas.region = Rect2(288, 352, 16, 16)
		sprite.texture = atlas
	elif kind == "weapon":
		sprite.texture = preload("res://assets/Flintlock/flintlock_pistol.png")
		sprite.region_enabled = true
		sprite.region_rect = Rect2(8, 4, 34, 15)
		sprite.scale = Vector2(0.35, 0.35)
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/Flintlock/white_background.gdshader")
		sprite.material = material
	add_child(sprite)
	z_index = 12

func _physics_process(delta: float) -> void:
	age += delta
	if collecting:
		_animate_collection(delta)
		return
	sprite.position.y = sin(age * 4.0) * 1.5 - 3.0
	if not is_instance_valid(player) or player.dead or player.fall_time > 0.0:
		return
	if global_position.distance_to(player.global_position) > 12.0:
		return
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return
	if kind == "coin":
		player.add_coins(amount)
		Audio.play("coin")
	elif kind == "health":
		if not player.heal(amount):
			return
		Audio.play("heal")
	else:
		player.upgrade_weapon()
		Audio.play("purchase")
	queue_free()

func collect_automatically(delay: float = 0.0) -> void:
	if collecting or kind != "coin" or is_queued_for_deletion():
		return
	collecting = true
	flight_delay = delay
	flight_start = global_position
	flight_control = flight_start + Vector2(0, -32)
	z_index = 30

func _animate_collection(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	flight_delay -= delta
	if flight_delay > 0.0:
		return
	flight_time = minf(0.65, flight_time + delta)
	var progress := flight_time / 0.65
	var eased := progress * progress
	var target := player.global_position + Vector2(0, -6)
	var first := flight_start.lerp(flight_control, eased)
	var second := flight_control.lerp(target, eased)
	global_position = first.lerp(second, eased)
	sprite.position.y = 0.0
	sprite.rotation = progress * TAU
	sprite.scale = Vector2.ONE * lerpf(1.0, 0.65, progress)
	if flight_time >= 0.65:
		player.add_coins(amount)
		Audio.play("coin")
		queue_free()
