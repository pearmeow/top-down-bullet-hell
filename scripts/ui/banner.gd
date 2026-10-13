extends Label

## Big centered announcement: "Room cleared" when an encounter ends, the boss's name when it appears.

var shown_clears: Dictionary = {}
var announced_boss := false
var tween: Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_top = -150
	offset_bottom = -100
	add_theme_font_size_override("font_size", 36)
	add_theme_constant_override("shadow_offset_x", 3)
	add_theme_constant_override("shadow_offset_y", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

func _process(_delta: float) -> void:
	for encounter in get_tree().get_nodes_in_group("encounters"):
		if encounter.cleared and not shown_clears.has(encounter):
			shown_clears[encounter] = true
			if not encounter.boss_room:
				announce("Room cleared", Color("cfb58a"))
	if not announced_boss:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if "DISPLAY_NAME" in enemy:
				announced_boss = true
				announce(enemy.DISPLAY_NAME, Color("d9604f"))

func announce(message: String, color: Color) -> void:
	text = message
	add_theme_color_override("font_color", color)
	if tween != null:
		tween.kill()
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 1.3
	modulate.a = 0.0
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.1)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.4)
