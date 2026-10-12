extends RefCounted

## Shared look for the HUD and every menu: pixel font, parchment text, brass-framed buttons,
## plus the in-game crosshair cursor.

const FONT := preload("res://assets/Fonts/PixelifySans.ttf")
const PARCHMENT := Color("cfb58a")
const HIGHLIGHT := Color("f1dcb0")
const BRASS := Color("94774d")
const IRON := Color("302b29")
const INK := Color("110f12")
const BLOOD := Color("87342e")

static var crosshair: ImageTexture

static func make_theme() -> Theme:
	var result := Theme.new()
	var font: FontFile = FONT
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", PARCHMENT)
	result.set_color("font_shadow_color", "Label", INK)
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 1)
	for state in ["normal", "hover", "pressed", "disabled"]:
		result.set_stylebox(state, "Button", _button_box(state))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = HIGHLIGHT
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_color("font_color", "Button", PARCHMENT)
	for name in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		result.set_color(name, "Button", HIGHLIGHT)
	result.set_color("font_disabled_color", "Button", Color("6b5f50"))
	result.set_color("font_color", "CheckButton", PARCHMENT)
	result.set_color("font_hover_color", "CheckButton", HIGHLIGHT)
	result.set_color("font_focus_color", "CheckButton", HIGHLIGHT)
	result.set_color("font_pressed_color", "CheckButton", HIGHLIGHT)
	result.set_color("font_hover_pressed_color", "CheckButton", HIGHLIGHT)
	result.set_stylebox("panel", "PanelContainer", panel_box())
	var track := StyleBoxFlat.new()
	track.bg_color = INK
	track.border_color = BRASS
	track.set_border_width_all(1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	result.set_stylebox("slider", "HSlider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = BLOOD
	result.set_stylebox("grabber_area", "HSlider", filled)
	result.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var tooltip := panel_box()
	tooltip.set_content_margin_all(6)
	result.set_stylebox("panel", "TooltipPanel", tooltip)
	result.set_color("font_color", "TooltipLabel", PARCHMENT)
	result.set_font_size("font_size", "TooltipLabel", 14)
	return result

static func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.08, 0.97)
	box.border_color = Color(0.58, 0.47, 0.3)
	box.set_border_width_all(2)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

static func _button_box(state: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = {"normal": IRON, "hover": Color("4a3f37"), "pressed": INK, "disabled": Color("1d191a")}[state]
	box.border_color = BRASS if state != "disabled" else Color("4d4234")
	box.set_border_width_all(2)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

## Swaps the OS pointer for a pixel crosshair during play, and back to the arrow for menus.
static func use_crosshair(enabled: bool) -> void:
	if not enabled:
		Input.set_custom_mouse_cursor(null)
		return
	if crosshair == null:
		var image := Image.create(19, 19, false, Image.FORMAT_RGBA8)
		for pass_index in 2:
			var color := INK if pass_index == 0 else HIGHLIGHT
			var grow := 1 if pass_index == 0 else 0
			for offset in range(3, 8):
				for side in [Vector2i(9 - offset, 9), Vector2i(9 + offset, 9), Vector2i(9, 9 - offset), Vector2i(9, 9 + offset)]:
					_plot(image, side, grow, color)
			_plot(image, Vector2i(9, 9), grow, color)
		crosshair = ImageTexture.create_from_image(image)
	Input.set_custom_mouse_cursor(crosshair, Input.CURSOR_ARROW, Vector2(9, 9))

static func _plot(image: Image, point: Vector2i, grow: int, color: Color) -> void:
	for y in range(point.y - grow, point.y + grow + 1):
		for x in range(point.x - grow, point.x + grow + 1):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)
