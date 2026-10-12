extends Node2D

## Small bar under the player's feet that fills while the dodge roll recharges,
## then blinks once when it's ready again.

var player: CharacterBody2D
var ready_flash := 0.0
var was_cooling := false

func _ready() -> void:
	z_index = 25

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	global_position = player.global_position + Vector2(0, 7)
	var cooling: bool = player.cooldown > 0.0 and player.roll_time <= 0.0
	if was_cooling and not cooling:
		ready_flash = 0.25
	was_cooling = cooling
	ready_flash = maxf(0.0, ready_flash - delta)
	visible = (cooling or ready_flash > 0.0) and not player.dead
	queue_redraw()

func _draw() -> void:
	var total: float = maxf(0.01, player.roll_cooldown)
	var fraction := 1.0 if ready_flash > 0.0 else clampf(1.0 - player.cooldown / total, 0.0, 1.0)
	draw_rect(Rect2(-8, 0, 16, 3), Color(0.05, 0.04, 0.05, 0.85))
	var color := Color("f1dcb0") if ready_flash > 0.0 else Color("94774d")
	draw_rect(Rect2(-7, 1, 14.0 * fraction, 1), color)
