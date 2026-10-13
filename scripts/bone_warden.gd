extends "res://scripts/skeleton.gd"

const BAR_SCRIPT := preload("res://scripts/boss_health_bar.gd")
const DISPLAY_NAME := "Bone Warden"

var bar: Control

func _ready() -> void:
	super()
	if is_instance_valid(encounter) and encounter.hud != null:
		bar = BAR_SCRIPT.new()
		bar.boss = self
		bar.font = encounter.hud.ui_theme.default_font
		bar.display_name = DISPLAY_NAME
		encounter.hud.add_child(bar)

func _exit_tree() -> void:
	if is_instance_valid(bar):
		bar.queue_free()
