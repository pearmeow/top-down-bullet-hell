extends "res://scripts/skeleton.gd"

## The Maw: a demon boss built on skeleton.gd. It keeps the inherited chase, windup,
## health and death handling, then adds bullet volleys and (from phase 2) a telegraphed
## charge that slams into walls. Health thresholds move it through three phases.

const BAR_SCRIPT := preload("res://scripts/boss_health_bar.gd")
const DISPLAY_NAME := "The Maw"
const PLAYTEST_HEALTH := 24
const MOUTH := Vector2(0, -18)
const CONTACT_RANGE := 22.0
# Bullet speeds stay below the player's 90 px/s walk so every pattern can be outpaced.
const BURST_SPEED := 95.0
const SPIRAL_SPEED := 70.0
const SPREAD_SPEED := 80.0
const SLAM_SPEED := 75.0
const CHARGE_SPEED := 240.0
const PHASE_TINTS := [Color(1, 1, 1), Color(1.15, 0.85, 0.8), Color(1.35, 0.7, 0.7)]
const BULLET_TINTS := [Color(1.0, 0.75, 0.45), Color(1.0, 0.5, 0.8), Color(1.0, 0.35, 0.3)]
const PHASE_GAPS := [1.4, 1.1, 0.9]
const CHARGE_GAPS := [0.0, 4.0, 2.6]
const SPEEDS := [34.0, 38.0, 46.0]

var phase := 1
var state := "chase"
var state_time := 0.0
var charge_timer := 3.0
var charge_direction := Vector2.RIGHT
var volley := ""
var steps_left := 0
var step_interval := 0.0
var step_clock := 0.0
var spiral_angle := 0.0
var spiral_turn := 1.0
var volley_count := 0
var bar: Control

func _ready() -> void:
	super()
	if attack_pace > 1.0:
		max_health = PLAYTEST_HEALTH
		health = max_health
	if is_instance_valid(encounter) and encounter.hud != null:
		bar = BAR_SCRIPT.new()
		bar.boss = self
		bar.font = encounter.hud.ui_theme.default_font
		bar.display_name = DISPLAY_NAME
		bar.phase_count = 3
		encounter.hud.add_child(bar)

func _exit_tree() -> void:
	if is_instance_valid(bar):
		bar.queue_free()

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player) or player.dead or grace > 0.0:
		state = "chase"
		volley = ""
		sprite.speed_scale = 1.0
		queue_redraw()
		super(delta)
		return
	if state == "chase":
		super(delta)
		_tick_volley(delta)
		charge_timer -= delta
		if phase >= 2 and charge_timer <= 0.0 and volley.is_empty() and windup <= 0.0 \
				and global_position.distance_to(player.global_position) > 60.0:
			_begin_charge()
	else:
		_tick_charge(delta)
	if global_position.distance_to(player.global_position) <= CONTACT_RANGE:
		player.take_damage(1)

func _tick_volley(delta: float) -> void:
	if volley.is_empty():
		return
	# Hold the inherited attack timer while a volley plays out, then leave the phase's gap.
	attack_timer = PHASE_GAPS[phase - 1] * attack_pace
	step_clock -= delta
	while steps_left > 0 and step_clock <= 0.0:
		_fire_step()
		steps_left -= 1
		step_clock += step_interval
	if steps_left == 0:
		volley = ""

func _begin_charge() -> void:
	state = "aim"
	state_time = 0.9 if phase == 2 else 0.7
	velocity = Vector2.ZERO
	charge_direction = global_position.direction_to(player.global_position)
	Audio.play("boss_charge")

func _tick_charge(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	state_time -= delta
	if state == "aim":
		# Track the player for most of the telegraph, then lock in so a sidestep works.
		if state_time > 0.25:
			charge_direction = global_position.direction_to(player.global_position)
		sprite.modulate = Color(2.5, 0.7, 0.7) if flash > 0.0 else Color(1.8, 0.9, 0.6)
		sprite.position.x = sin(state_time * 80.0) * 1.0
		sprite.flip_h = charge_direction.x < 0.0
		sprite.play("idle")
		queue_redraw()
		if state_time <= 0.0:
			state = "charge"
			state_time = 1.6
			sprite.position.x = 0.0
			queue_redraw()
	elif state == "charge":
		sprite.modulate = Color(2.5, 0.7, 0.7) if flash > 0.0 else PHASE_TINTS[phase - 1]
		sprite.play("walk")
		sprite.speed_scale = 2.5
		velocity = charge_direction * CHARGE_SPEED
		move_and_slide()
		if get_slide_collision_count() > 0:
			_slam()
		elif state_time <= 0.0:
			_recover(0.4)
	elif state == "recover":
		sprite.modulate = Color(2.5, 0.7, 0.7) if flash > 0.0 else PHASE_TINTS[phase - 1]
		sprite.play("idle")
		velocity = Vector2.ZERO
		if state_time <= 0.0:
			state = "chase"
			charge_timer = CHARGE_GAPS[phase - 1]
			attack_timer = 0.5 * attack_pace

func _slam() -> void:
	var count := 10 if phase == 2 else 14
	var offset := randf() * TAU
	for index in count:
		_fire(Vector2.RIGHT.rotated(offset + TAU * index / count), SLAM_SPEED)
	_shake_camera()
	Audio.play("boss_slam")
	_recover(0.9)

func _recover(duration: float) -> void:
	state = "recover"
	state_time = duration
	sprite.speed_scale = 1.0

func _shake_camera() -> void:
	var camera := get_tree().current_scene.get_node_or_null("Camera2D") as Camera2D
	if camera == null or not Settings.screen_shake:
		return
	var tween := camera.create_tween()
	for index in 5:
		tween.tween_property(camera, "offset", Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func _draw() -> void:
	if state != "aim":
		return
	# Telegraph line along the locked-in charge path.
	var alpha := 0.35 if state_time > 0.25 else 0.75
	draw_line(MOUTH, MOUTH + charge_direction * 220.0, Color(1.0, 0.25, 0.2, alpha), 3.0)

func take_damage(amount: int) -> void:
	super(amount)
	if dead:
		return
	var next_phase := 1
	if health * 3 <= max_health:
		next_phase = 3
	elif health * 3 <= max_health * 2:
		next_phase = 2
	if next_phase > phase:
		_enter_phase(next_phase)

func _enter_phase(value: int) -> void:
	phase = value
	Audio.play("boss_phase")
	if is_instance_valid(bar):
		bar.current_phase = phase
	state = "chase"
	volley = ""
	windup = 0.0
	speed = SPEEDS[phase - 1]
	base_tint = PHASE_TINTS[phase - 1]
	sprite.position.x = 0.0
	sprite.speed_scale = 1.0
	queue_redraw()
	# Reuse the spawn grace from skeleton.gd as a short stagger between phases.
	grace = 1.2
	flash = 0.5
	attack_timer = 0.6 * attack_pace
	charge_timer = 1.5
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()

## Called by skeleton.gd when a windup finishes.
func _throw() -> void:
	if dead or player.dead:
		return
	volley_count += 1
	step_clock = 0.0
	if phase == 1:
		_start("burst", 3, 0.35)
	elif phase == 2:
		spiral_turn = 1.0
		_start("spiral", 18, 0.12)
	elif volley_count % 2 == 0:
		_start("spread", 2, 0.5)
	else:
		spiral_turn = -spiral_turn
		_start("spiral", 16, 0.14)

func _start(kind: String, steps: int, interval: float) -> void:
	volley = kind
	steps_left = steps
	step_interval = interval

func _fire_step() -> void:
	var toward := (global_position + MOUTH).direction_to(player.global_position)
	if volley == "burst":
		# Re-aims every burst, so the player has to keep moving sideways.
		for index in range(-2, 3):
			_fire(toward.rotated(deg_to_rad(index * 10.0)), BURST_SPEED)
	elif volley == "spiral":
		var arms := 2 if phase == 2 else 3
		spiral_angle += deg_to_rad(14.0 if phase == 2 else 12.0) * spiral_turn
		for arm in arms:
			_fire(Vector2.RIGHT.rotated(spiral_angle + TAU * arm / arms), SPIRAL_SPEED)
	elif volley == "spread":
		# Nine shots over 120 degrees; the second wave fills the gaps of the first.
		var offset := 7.5 if steps_left == 1 else 0.0
		for index in range(-4, 5):
			_fire(toward.rotated(deg_to_rad(index * 15.0 + offset)), SPREAD_SPEED)

func _fire(direction: Vector2, bullet_speed: float) -> void:
	var projectile := PROJECTILE.instantiate() as CharacterBody2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + MOUTH
	projectile.velocity = direction * bullet_speed
	projectile.lifetime = 5.0
	projectile.modulate = BULLET_TINTS[phase - 1]
	Audio.play("enemy_shoot")
