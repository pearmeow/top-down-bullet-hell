extends HBoxContainer

## Bottom-left row of icons for upgrades the player owns. Hover an icon for its description.
## Gameplay code adds entries through CombatHUD.add_upgrade(); the two upgrades that exist
## today (flintlock upgrade, skull familiar) are detected here until they report themselves.

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")

var player: CharacterBody2D
var services: Node2D
var icons: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 16
	offset_top = -52
	offset_bottom = -16
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 6)

func add_upgrade(id: String, icon: Texture2D, description: String, count := 1) -> void:
	if icons.has(id):
		var existing: PanelContainer = icons[id]
		existing.tooltip_text = description
		(existing.get_node("Count") as Label).text = "x%d" % count if count > 1 else ""
		return
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.08, 0.85)
	box.border_color = UI_STYLE.BRASS
	box.set_border_width_all(2)
	box.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", box)
	frame.custom_minimum_size = Vector2(36, 36)
	frame.tooltip_text = description
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var picture := TextureRect.new()
	picture.texture = icon
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	var number := Label.new()
	number.name = "Count"
	number.text = "x%d" % count if count > 1 else ""
	number.add_theme_font_size_override("font_size", 12)
	number.size_flags_horizontal = Control.SIZE_SHRINK_END
	number.size_flags_vertical = Control.SIZE_SHRINK_END
	frame.add_child(number)
	add_child(frame)
	icons[id] = frame

func remove_upgrade(id: String) -> void:
	if icons.has(id):
		(icons[id] as Node).queue_free()
		icons.erase(id)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if player.weapon_upgraded and not icons.has("flintlock"):
		var gun := AtlasTexture.new()
		gun.atlas = preload("res://assets/GunsAssetPack/Individual_Gun_Sprites/No_Outline/Revolver.png")
		add_upgrade("flintlock", gun, "Flintlock upgrade\nMore damage, faster shots")
	if services != null and services.has_familiar and not icons.has("familiar"):
		add_upgrade("familiar", preload("res://assets/Character/Props/Individual_Props/skull_01.png"), "Skull familiar\nFollows you and shoots enemies")
