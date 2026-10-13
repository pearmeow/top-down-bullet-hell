extends ColorRect

## Red vignette that pulses when the player loses health, plus a small camera shake.

const SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float edge = smoothstep(0.45, 1.0, distance(UV, vec2(0.5)) * 1.4);
	COLOR = vec4(0.75, 0.08, 0.06, edge * strength);
}
"""

var strength := 0.0
var level: Node2D

func configure(player: CharacterBody2D, value: Node2D) -> void:
	level = value
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = shader
	var last := [player.health]
	player.health_changed.connect(func(current: int, _maximum: int) -> void:
		if current < last[0]:
			strength = 0.7
			_shake()
		last[0] = current)

func _process(delta: float) -> void:
	strength = maxf(0.0, strength - delta * 2.2)
	(material as ShaderMaterial).set_shader_parameter("strength", strength)
	visible = strength > 0.0

func _shake() -> void:
	if not Settings.screen_shake:
		return
	var camera := level.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var tween := camera.create_tween()
	for index in 4:
		tween.tween_property(camera, "offset", Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.035)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.035)
