extends Control

## Esc / P pauses the run. Runs while the tree is paused. Esc is left to the shop while it is open.

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")
const SETTINGS_PANEL := preload("res://scripts/ui/settings_panel.gd")
const TITLE_SCENE := "res://scenes/ui/title.tscn"

var hud: CanvasLayer
var menu: VBoxContainer
var settings: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	var panel := PanelContainer.new()
	stack.add_child(panel)
	menu = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(260, 0)
	menu.add_theme_constant_override("separation", 10)
	panel.add_child(menu)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	_add_button("Resume", resume)
	_add_button("Settings", _open_settings)
	_add_button("Restart run", func() -> void: _leave(""))
	_add_button("Quit to title", func() -> void: _leave(TITLE_SCENE))
	settings = SETTINGS_PANEL.new()
	settings.hide()
	settings.closed.connect(_close_settings)
	stack.add_child(settings)
	hide()

func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	menu.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode != KEY_ESCAPE and event.physical_keycode != KEY_P:
		return
	if visible:
		if settings.visible:
			settings.close()
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif _can_pause():
		pause()
		get_viewport().set_input_as_handled()

func _can_pause() -> bool:
	var player: CharacterBody2D = hud.player
	if not is_instance_valid(player) or player.dead or player.menu_open or hud.won:
		return false
	return hud.services == null or not hud.services.shop_open

func pause() -> void:
	get_tree().paused = true
	UI_STYLE.use_crosshair(false)
	move_to_front()
	show()
	menu.get_parent().show()
	settings.hide()
	(menu.get_child(1) as Button).grab_focus()

func resume() -> void:
	hide()
	get_tree().paused = false
	UI_STYLE.use_crosshair(true)

func _open_settings() -> void:
	menu.get_parent().hide()
	settings.open()

func _close_settings() -> void:
	menu.get_parent().show()
	(menu.get_child(2) as Button).grab_focus()

func _leave(scene: String) -> void:
	get_tree().paused = false
	if scene.is_empty():
		get_tree().reload_current_scene()
	else:
		UI_STYLE.use_crosshair(false)
		get_tree().change_scene_to_file(scene)
