extends VBoxContainer

## Curses, buffs and debuffs on the player, shown as labeled chips with an optional countdown.
## Gameplay code calls CombatHUD.show_status() / clear_status(); nothing uses it yet.

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")

var chips: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 16
	offset_bottom = -60
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## seconds < 0 means the status lasts until clear_status() is called.
func show_status(id: String, label: String, color: Color, seconds := -1.0) -> void:
	clear_status(id)
	var chip := Label.new()
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", color)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.08, 0.85)
	box.border_color = color.darkened(0.3)
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	chip.add_theme_stylebox_override("normal", box)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(chip)
	chips[id] = {"node": chip, "label": label, "left": seconds}
	_refresh(chips[id])

func clear_status(id: String) -> void:
	if chips.has(id):
		(chips[id].node as Node).queue_free()
		chips.erase(id)

func _process(delta: float) -> void:
	for id in chips.keys():
		var chip: Dictionary = chips[id]
		if chip.left < 0.0:
			continue
		chip.left -= delta
		if chip.left <= 0.0:
			clear_status(id)
		else:
			_refresh(chip)

func _refresh(chip: Dictionary) -> void:
	var text: String = chip.label
	if chip.left >= 0.0:
		text += "  %ds" % ceili(chip.left)
	(chip.node as Label).text = text
