extends Control

## Main menu shown on launch: Play, Settings, Quit, over drifting embers.

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")
const SETTINGS_PANEL := preload("res://scripts/ui/settings_panel.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const GAME_TITLE := "Top-Down Bullet Hell"

var menu: VBoxContainer
var settings: PanelContainer
var embers: Array[Vector3] = []
var boss_art: TextureRect
var age := 0.0

func _ready() -> void:
	theme = UI_STYLE.make_theme()
	Audio.play_music("title")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UI_STYLE.use_crosshair(false)
	for index in 40:
		embers.append(Vector3(randf(), randf(), randf_range(0.3, 1.0)))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	boss_art = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/Enemies/dungeon_characters.png")
	atlas.region = Rect2(16, 428, 32, 36)
	boss_art.texture = atlas
	boss_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_art.custom_minimum_size = Vector2(96, 108)
	boss_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss_art.modulate = Color(1, 1, 1, 0.85)
	column.add_child(boss_art)
	var title := Label.new()
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A roguelike shooter"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	column.add_child(spacer)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.custom_minimum_size = Vector2(240, 0)
	column.add_child(menu)
	_add_button("Play", _play)
	_add_button("Settings", _open_settings)
	if not OS.has_feature("web"):
		_add_button("Quit", func() -> void: get_tree().quit())
	settings = SETTINGS_PANEL.new()
	settings.hide()
	settings.closed.connect(_close_settings)
	column.add_child(settings)
	var controls := Label.new()
	controls.text = "WASD move  ·  Mouse aim / shoot  ·  Space dodge  ·  E interact  ·  Tab map  ·  Esc pause"
	controls.add_theme_font_size_override("font_size", 14)
	controls.modulate = Color(1, 1, 1, 0.5)
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.grow_horizontal = Control.GROW_DIRECTION_BOTH
	controls.offset_top = -40
	controls.offset_bottom = -16
	add_child(controls)
	(menu.get_child(0) as Button).grab_focus()

func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	menu.add_child(button)

func _play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _open_settings() -> void:
	menu.hide()
	settings.open()

func _close_settings() -> void:
	menu.show()
	(menu.get_child(1) as Button).grab_focus()

func _process(delta: float) -> void:
	age += delta
	# Cycle the Maw's four idle frames.
	(boss_art.texture as AtlasTexture).region.position.x = 16 + 32 * (int(age * 6.0) % 4)
	for index in embers.size():
		var ember := embers[index]
		ember.y -= delta * 0.04 * ember.z
		ember.x += sin(age * 0.7 + index) * delta * 0.004
		if ember.y < -0.02:
			ember = Vector3(randf(), 1.02, randf_range(0.3, 1.0))
		embers[index] = ember
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d0b0f"))
	for ember in embers:
		var point := Vector2(ember.x, ember.y) * size
		var glow := Color(0.85, 0.35, 0.2, 0.25 + 0.5 * ember.z)
		draw_rect(Rect2(point.floor(), Vector2(2, 2) * ceilf(ember.z * 2.0)), glow)
