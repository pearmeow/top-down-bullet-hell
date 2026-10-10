extends CanvasLayer

var ui_theme: Theme
var won := false
var player: CharacterBody2D

func _ready() -> void:
	ui_theme = Theme.new()
	var font := preload("res://assets/Fonts/PixelifySans.ttf")
	font.antialiasing = 0
	ui_theme.default_font = font
	ui_theme.default_font_size = 18
	ui_theme.set_color("font_color", "Label", Color("cfb58a"))
	ui_theme.set_color("font_shadow_color", "Label", Color("110f12"))
	ui_theme.set_constant("shadow_offset_x", "Label", 1)
	ui_theme.set_constant("shadow_offset_y", "Label", 1)
	for child in get_children():
		if child is Control:
			child.theme = ui_theme
	$DeathPanel.hide()
	$DeathPanel/Center/Restart.pressed.connect(_restart)

func bind_player(value: CharacterBody2D) -> void:
	player = value
	player.health_changed.connect(_update_health)
	player.died.connect(_show_death)
	_update_health(player.health, player.max_health)

func _update_health(current: int, maximum: int) -> void:
	$Health.set_health(current, maximum)

func _show_death() -> void:
	$DeathPanel.show()
	$DeathPanel/Center/Restart.grab_focus()

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
	if get_parent().playtest_mode:
		var notice := Label.new()
		notice.theme = ui_theme
		notice.position = Vector2(320, 20)
		notice.text = "PLAYTEST"
		notice.modulate = Color(0.65, 0.65, 0.7)
		add_child(notice)

func _buy(item: String) -> void:
	shop_message.text = services.buy(item)

func set_interaction(value: String) -> void:
	interaction_label.text = value

func open_shop() -> void:
	shop_panel.show()
	shop_message.text = "E or Escape · Leave shop"

func close_shop() -> void:
	shop_panel.hide()

func show_victory() -> void:
	won = true
	player.menu_open = true
	$DeathPanel/Center/Title.text = "Catacombs cleared"
	$DeathPanel/Center/Restart.text = "New run (R)"
	$DeathPanel.show()
	$DeathPanel/Center/Restart.grab_focus()
