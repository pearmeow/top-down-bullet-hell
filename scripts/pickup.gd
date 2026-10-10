extends Node2D

var kind := "coin"
var amount := 1
var player: CharacterBody2D
var sprite: Sprite2D
var age := 0.0

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
	elif kind == "health":
		if not player.heal(amount):
			return
	else:
		player.upgrade_weapon()
	queue_free()
