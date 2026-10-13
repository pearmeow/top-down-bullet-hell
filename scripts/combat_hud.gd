extends CanvasLayer

var ui_theme: Theme
var won := false
var player: CharacterBody2D

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")
var run_stats: Node
var upgrade_bar: HBoxContainer
var status_bar: VBoxContainer
var stats_label: Label

func _ready() -> void:
	ui_theme = UI_STYLE.make_theme()
	for child in get_children():
		if child is Control:
			child.theme = ui_theme
	$DeathPanel.hide()
	$DeathPanel/Center/Restart.pressed.connect(_restart)
	$DeathPanel/Center.offset_top = -150.0
	$DeathPanel/Center.offset_bottom = 150.0
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.modulate = Color(1, 1, 1, 0.85)
	$DeathPanel/Center.add_child(stats_label)
	$DeathPanel/Center.move_child(stats_label, 1)
	var quit := Button.new()
	quit.text = "Quit to title"
	quit.pressed.connect(func() -> void:
		UI_STYLE.use_crosshair(false)
		get_tree().change_scene_to_file("res://scenes/ui/title.tscn"))
	$DeathPanel/Center.add_child(quit)

func bind_player(value: CharacterBody2D) -> void:
	player = value
	player.health_changed.connect(_update_health)
	player.died.connect(_show_death)
	_update_health(player.health, player.max_health)
	UI_STYLE.use_crosshair(true)

## Builds the HUD pieces that need the generated level: map, run tracking, combat feedback,
## upgrade/status bars, banner and pause menu.
func _add_components(level: Node2D) -> void:
	var hit_flash := ColorRect.new()
	hit_flash.set_script(preload("res://scripts/ui/hit_flash.gd"))
	add_child(hit_flash)
	move_child(hit_flash, 0)
	hit_flash.configure(player, level)
	run_stats = Node.new()
	run_stats.set_script(preload("res://scripts/ui/run_stats.gd"))
	run_stats.name = "RunStats"
	level.add_child(run_stats)
	run_stats.configure(level)
	var numbers := Node2D.new()
	numbers.set_script(preload("res://scripts/ui/damage_numbers.gd"))
	level.add_child(numbers)
	var dodge := Node2D.new()
	dodge.set_script(preload("res://scripts/ui/dodge_indicator.gd"))
	dodge.player = player
	level.add_child(dodge)
	var minimap := Control.new()
	minimap.set_script(preload("res://scripts/ui/minimap.gd"))
	add_child(minimap)
	minimap.configure(level)
	upgrade_bar = HBoxContainer.new()
	upgrade_bar.set_script(preload("res://scripts/ui/upgrade_bar.gd"))
	upgrade_bar.theme = ui_theme
	upgrade_bar.player = player
	upgrade_bar.services = services
	add_child(upgrade_bar)
	status_bar = VBoxContainer.new()
	status_bar.set_script(preload("res://scripts/ui/status_bar.gd"))
	status_bar.theme = ui_theme
	add_child(status_bar)
	var banner := Label.new()
	banner.set_script(preload("res://scripts/ui/banner.gd"))
	banner.theme = ui_theme
	add_child(banner)
	var pause_menu := Control.new()
	pause_menu.set_script(preload("res://scripts/ui/pause_menu.gd"))
	pause_menu.theme = ui_theme
	pause_menu.hud = self
	add_child(pause_menu)

## For gameplay code: show an owned upgrade in the bottom-left bar (count > 1 shows "x2" etc).
func add_upgrade(id: String, icon: Texture2D, description: String, count := 1) -> void:
	upgrade_bar.add_upgrade(id, icon, description, count)

## For gameplay code: show a curse/buff on the player. seconds < 0 lasts until clear_status().
func show_status(id: String, label: String, color: Color, seconds := -1.0) -> void:
	status_bar.show_status(id, label, color, seconds)

func clear_status(id: String) -> void:
	status_bar.clear_status(id)

func _show_end_panel() -> void:
	UI_STYLE.use_crosshair(false)
	stats_label.text = run_stats.summary() if run_stats != null else ""
	$DeathPanel.show()
	$DeathPanel/Center/Restart.grab_focus()

func _update_health(current: int, maximum: int) -> void:
	$Health.set_health(current, maximum)

func _show_death() -> void:
	Audio.stop_music(0.6)
	_show_end_panel()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(player) and (player.dead or won) and event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == KEY_R:
			_restart()
			get_viewport().set_input_as_handled()

func _restart() -> void:
	get_tree().call_deferred("reload_current_scene")

func set_encounter_text(value: String) -> void:
	$EncounterStatus.text = value

var services: Node2D
var coin_counter: Control
var interaction_label: Label
var shop_panel: PanelContainer
var shop_message: Label

func bind_services(value: Node2D) -> void:
	services = value
	coin_counter = Control.new()
	coin_counter.set_script(preload("res://scripts/coin_counter.gd"))
	coin_counter.position = Vector2(202, 16)
	coin_counter.size = Vector2(100, 30)
	coin_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_counter.font = ui_theme.default_font
	add_child(coin_counter)
	player.coins_changed.connect(coin_counter.set_coins)
	coin_counter.set_coins(player.coins)
	interaction_label = Label.new()
	interaction_label.theme = ui_theme
	interaction_label.position = Vector2(16, 80)
	interaction_label.modulate = Color(0.81, 0.71, 0.54)
	add_child(interaction_label)
	shop_panel = PanelContainer.new()
	shop_panel.theme = ui_theme
	shop_panel.position = Vector2(16, 112)
	shop_panel.custom_minimum_size = Vector2(300, 0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.07, 0.05, 0.08, 0.97)
	frame.border_color = Color(0.58, 0.47, 0.3)
	frame.set_border_width_all(2)
	frame.content_margin_left = 16
	frame.content_margin_right = 16
	frame.content_margin_top = 12
	frame.content_margin_bottom = 12
	shop_panel.add_theme_stylebox_override("panel", frame)
	add_child(shop_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	shop_panel.add_child(box)
	var title := Label.new()
	title.text = "The Catacomb Trader"
	title.modulate = Color(0.81, 0.71, 0.54)
	box.add_child(title)
	for item in [["heal", "Restore 1 health · 4 coins"], ["weapon", "Flintlock upgrade · 8 coins"], ["familiar", "Recruit skull familiar · 10 coins"]]:
		var button := Button.new()
		button.text = item[1]
		button.pressed.connect(_buy.bind(item[0]))
		box.add_child(button)
	shop_message = Label.new()
	shop_message.text = "E or Escape · Leave shop"
	box.add_child(shop_message)
	shop_panel.hide()
	_add_components(get_parent())
	if get_parent().playtest_mode:
		var notice := Label.new()
		notice.theme = ui_theme
		notice.position = Vector2(320, 20)
		notice.text = "PLAYTEST"
		notice.modulate = Color(0.65, 0.65, 0.7)
		add_child(notice)

func _buy(item: String) -> void:
	var coins_before: int = player.coins
	shop_message.text = services.buy(item)
	Audio.play("purchase" if player.coins < coins_before else "denied")

func set_interaction(value: String) -> void:
	interaction_label.text = value

func open_shop() -> void:
	Audio.play("shop_open")
	shop_panel.show()
	shop_message.text = "E or Escape · Leave shop"

func close_shop() -> void:
	shop_panel.hide()

func show_victory() -> void:
	won = true
	Audio.play_music("victory", 0.5)
	player.menu_open = true
	$DeathPanel/Center/Title.text = "Catacombs cleared"
	$DeathPanel/Center/Restart.text = "New run (R)"
	if run_stats != null:
		run_stats.finished = true
	_show_end_panel()
